/*<info serverAlias="DBRMS-bodb_RMS" executers="bodbRMSNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[RMS_Rpt_ComboParlay_Winloss_Ag]
	@Recommends		VARCHAR(MAX),
	@fromdate		DATETIME,
	@todate			DATETIME,
	@movebetsday	DATETIME,
	@balanceUpday	DATETIME = NULL,
	@sporttype		VARCHAR(100) = '',
	@selection		VARCHAR(MAX) = '',
	@ParlayType		VARCHAR(10) = '',
	@LiveStatus		TINYINT = 3
AS

/*
	Created: 20160511@Winnie
	DB: DBRMS-bodb_RMS
	Task: Get report win loss for downlines by specific Agent

	Revisions:
		- 20170719@Winnie: Add MuayThai RedmineID: #79500	
		- 20180927@Jacob: Apply Extra PT and Super Comm to Report. RedmineID: #100951 	
		- 20190214@Jacob: Add Bet Builder RedmineID: #108694	
		- 20191026@Jacob: Winloss by master RedmineID: [#122137]	
		- 20191211@Jacob: Extra PT - Add new structure to support extra pt column on bettrans table #124194
		- 20200510@Percy: Add Penalty Shootout Combo [RedmineID: #133961]
		- 20201204@Danny: Separate Data of Virtual Soccer & Virtual Basketball  [RedmineID: #145926]
		- 20210218@Danny: Monitor Performance of GOF  [RedmineID: #149966]
		- 20210629@Danny: Add filtering by Customer Class[RedmineID: #156980]
		- 20220519@Danny: add filter by Live Status [RedmineID: #172691]
		- 20230420@Cherry: Add Site column (#186735)
		- 20230724@Kean: Include custid column to GroupBy condition (#191660)
	
	Parameter's Explanation:
		- @sporttype:
					. '1': soccer only
					. '-1': Combined other sports
					. '-2': Other sports
					. '-3': Combined sports
					. -4: saba soccer
					. -5: saba basketball
		- @ParlayType:
					. 1: Mix parlay
					. 2: Combo parlay
					. 3: Single Match Parlay
					. 4: Panalty shootout combo
					. 5: GOF
*/

BEGIN
	SET NOCOUNT ON

	-- selections
	BEGIN
		CREATE TABLE #tmpSelection (selection INT)

		-- all selections (2 --> 100)
		IF ',' + @selection + ',' LIKE '%,0,%'
		BEGIN
			SELECT @selection = '2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,64,65,66,67,68,69,70,71,72,73,74,75,76,77,78,79,80,81,82,83,84,85,86,87,88,89,90,91,92,93,94,95,96,97,98,99,100'
		
			INSERT INTO #tmpSelection (selection)
			SELECT value FROM STRING_SPLIT(@selection, ',')
		END
		-- 10UP (add 11 --> 100)
		ELSE IF ',' + @selection + ',' LIKE '%,10,%'
		BEGIN
			SELECT @selection = @selection + ',11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,64,65,66,67,68,69,70,71,72,73,74,75,76,77,78,79,80,81,82,83,84,85,86,87,88,89,90,91,92,93,94,95,96,97,98,99,100'
		
			INSERT INTO #tmpSelection (selection)
			SELECT value FROM STRING_SPLIT(@selection, ',')
		END
		ELSE
		BEGIN
			INSERT INTO #tmpSelection (selection)
			SELECT value FROM STRING_SPLIT(@selection, ',')
		END
	END

	-- sports
	BEGIN
		CREATE TABLE #tmpSport (sporttype INT)
		INSERT INTO #tmpSport (sporttype)
		SELECT value FROM STRING_SPLIT(@sporttype, ',')

		IF ',' + @sporttype + ',' LIKE '%,-2,%'
			INSERT INTO #tmpSport (sporttype)
			SELECT SportType FROM bodb02.dbo.Sports WITH (NOLOCK)
			WHERE SportType NOT IN (1,2,3,4,5,6,7,8,9,11,43,44)
				AND SportType <= 99
	END

	-- agent
	BEGIN
		CREATE TABLE #recommend (recommend INT)
		INSERT INTO #recommend (recommend)
		SELECT value FROM STRING_SPLIT(@recommends, ',')
	END

	-- get data
	BEGIN
		CREATE TABLE #bettype (bettype SMALLINT)

		-- Combo parlay
		DECLARE @ComboType TINYINT = 0 -- 1: mix parlay only, 2: combo parlay only, 3: combined
		
		IF ',' + @ParlayType + ',' LIKE '%,1,%' OR ',' + @ParlayType + ',' LIKE '%,2,%' OR  ',' + @ParlayType + ',' LIKE '%,5,%'
		BEGIN
			INSERT INTO #bettype (bettype)
			VALUES (29)

			SELECT	@ComboType = CASE	WHEN COUNT(DISTINCT value) = 3 AND SUM(DISTINCT CAST(value as SMALLINT)) = 8 THEN 7 
										WHEN COUNT(DISTINCT value) = 2 AND SUM(DISTINCT CAST(value as SMALLINT)) = 3 THEN 6
										WHEN COUNT(DISTINCT value) = 2 AND SUM(DISTINCT CAST(value as SMALLINT)) = 6 THEN 4
										WHEN COUNT(DISTINCT value) = 2 AND SUM(DISTINCT CAST(value as SMALLINT)) = 7 THEN 5
										WHEN COUNT(DISTINCT value) = 1 AND SUM(DISTINCT CAST(value as SMALLINT)) = 1 THEN 1
										WHEN COUNT(DISTINCT value) = 1 AND SUM(DISTINCT CAST(value as SMALLINT)) = 2 THEN 2
										WHEN COUNT(DISTINCT value) = 1 AND SUM(DISTINCT CAST(value as SMALLINT)) = 5 THEN 3
								END
			FROM STRING_SPLIT(@ParlayType, ',') WHERE value IN (1,2,5)
		END

		-- Single match parlay
		IF ',' + @ParlayType + ',' LIKE '%,3,%'
			INSERT INTO #bettype (bettype)
			VALUES (38)

		-- Penalty shootout combo
		IF ',' + @ParlayType + ',' LIKE '%,4,%'
			INSERT INTO #bettype (bettype)
			VALUES (376)

		DECLARE @f_date SMALLDATETIME, @t_date SMALLDATETIME

		CREATE TABLE #tmpSum
		(
			month			VARCHAR(7)
			,custid			INT
			,username		VARCHAR(50)
			,tickets_won	INT
			,tickets_lose	INT
			,stake_won		MONEY
			,stake_lose		MONEY
			,member_won		MONEY
			,member_lose	MONEY
			,ourPT_won		MONEY
			,ourPT_lose		MONEY
			,CustomerClass  SMALLINT
		)

		-- rmBettrans
		IF @ToDate > @MoveBetsDay
		BEGIN
			SELECT	@f_date = CASE WHEN @FromDate <= @MoveBetsDay THEN DATEADD(DAY, 1, @MoveBetsDay) ELSE @FromDate END
					,@t_date = @ToDate

			INSERT INTO #tmpSum
			(
				month 
				,custid
				,username
				,tickets_won
				,tickets_lose 
				,stake_won 
				,stake_lose
				,member_won 
				,member_lose
				,ourPT_won 
				,ourPT_lose
				,CustomerClass
			)
			SELECT
				CONVERT(VARCHAR(7), winlostdate, 120)
				,b.custid
				,b.username
				,SUM(CASE WHEN statusID = 112 THEN 1 ELSE 0 END) AS tickets_won
				,SUM(CASE WHEN statusID = 113 THEN 1 ELSE 0 END) AS tickets_lose
				,SUM(CASE WHEN statusID = 112 THEN stake * actualrate * (1 - tpositiontaking - CAST(ISNULL(epositiontaking, 0) AS DECIMAL(9,8))) ELSE 0 END) AS stake_won
				,SUM(CASE WHEN statusID = 113 THEN stake * actualrate * (1 - tpositiontaking - CAST(ISNULL(epositiontaking, 0) AS DECIMAL(9,8))) ELSE 0 END) AS stake_won
				,SUM(CASE WHEN statusID = 112 THEN -(winlost - actual_stake) * actualrate ELSE 0 END) AS member_won
				,SUM(CASE WHEN statusID = 113 THEN -(winlost - actual_stake) * actualrate ELSE 0 END) AS member_lose
				,SUM(CASE WHEN 1 - tpositiontaking = 0 THEN 0 ELSE CASE WHEN statusID = 112 THEN (-(winlost - actual_stake) * (1 - tpositiontaking - CAST(ISNULL(epositiontaking, 0) AS DECIMAL(9,8))) - scomm  + scomm * CAST(ISNULL(epositiontaking, 0) AS DECIMAL(9,8)) / (1 - tpositiontaking)) * actualrate ELSE 0 END END) AS ourPT_won
				,SUM(CASE WHEN 1 - tpositiontaking = 0 THEN 0 ELSE CASE WHEN statusID = 113 THEN (-(winlost - actual_stake) * (1 - tpositiontaking - CAST(ISNULL(epositiontaking, 0) AS DECIMAL(9,8))) - scomm  + scomm * CAST(ISNULL(epositiontaking, 0) AS DECIMAL(9,8)) / (1 - tpositiontaking)) * actualrate ELSE 0 END END) AS ourPT_lose
				,ci.CustomerClass
			FROM dbo.rmBettrans b WITH (NOLOCK)
				INNER JOIN #bettype bt ON b.bettype = bt.bettype
				INNER JOIN #tmpSelection s ON b.hdp2 = s.selection
				INNER JOIN #tmpSport sp ON b.transid2 = sp.sporttype
				INNER JOIN #recommend r ON r.recommend = b.recommend
				INNER JOIN bodb02.dbo.CustInfo ci WITH(NOLOCK) ON b.custid = ci.custid
			WHERE winlostdate BETWEEN @f_date AND @t_date
				AND statusID IN (112, 113)
				AND b.currency <> 20
				AND 1 = CASE
							WHEN b.bettype = 29 AND @ComboType IN (1, 2, 3, 4, 5, 6) THEN CASE
									WHEN @ComboType = 1 AND b.betteam = N'1' AND (b.oddsspread <> 1 OR b.oddsspread IS NULL) THEN 1
									WHEN @ComboType = 2 AND b.betteam <> N'1' THEN 1
									WHEN @ComboType = 3 AND b.betteam = N'1' AND b.oddsspread = 1 THEN 1
									WHEN @ComboType = 4 AND b.betteam = N'1' THEN 1
									WHEN @ComboType = 5 AND (b.betteam <> N'1' OR (b.betteam = N'1' AND b.oddsspread = 1)) THEN 1
									WHEN @ComboType = 6 AND (b.betteam <> N'1' OR (b.betteam = N'1' AND (b.oddsspread <> 1 OR b.oddsspread IS NULL))) THEN 1
									ELSE 0 END
							ELSE 1 END
				AND (CASE WHEN b.bettype = 29 THEN b.livehomescore ELSE b.liveindicator END = @LiveStatus OR @LiveStatus = 3)
			GROUP BY CONVERT(VARCHAR(7), winlostdate, 120), b.custid, b.username, ci.CustomerClass
		END

		-- rmSumWinloss
		IF @FromDate <= @MoveBetsDay AND @ToDate >= @BalanceUpDay
		BEGIN
			SELECT	@f_date = CASE WHEN @FromDate < @BalanceUpDay THEN @BalanceUpDay ELSE @FromDate END
					,@t_date = CASE WHEN @ToDate > @MoveBetsDay THEN @MoveBetsDay ELSE @ToDate END

			INSERT INTO #tmpSum
			(
				month 
				,custid
				,username
				,tickets_won
				,tickets_lose 
				,stake_won 
				,stake_lose
				,member_won 
				,member_lose
				,ourPT_won 
				,ourPT_lose
				,CustomerClass
			)
			SELECT 
				CONVERT(VARCHAR(7), winlostdate, 120)
				,a.custid
				,a.username
				,SUM(CASE WHEN statusID = 112 THEN betcount ELSE 0 END) AS tickets_won
				,SUM(CASE WHEN statusID = 113 THEN betcount ELSE 0 END) AS tickets_lose
				,SUM(CASE WHEN statusID = 112 THEN company_stake*actualrate - ISNULL(a.Extra_stake, 0) * actualrate ELSE 0 END) AS stake_won
				,SUM(CASE WHEN statusID = 113 THEN company_stake*actualrate - ISNULL(a.Extra_stake, 0) * actualrate ELSE 0 END) AS stake_lose
				,SUM(CASE WHEN statusID = 112 THEN -(a.winlost-a.stake)*actualrate ELSE 0 END) AS member_won
				,SUM(CASE WHEN statusID = 113 THEN -(a.winlost-a.stake)*actualrate ELSE 0 END) AS member_lose
				,SUM(CASE WHEN statusID = 112 THEN (company_winlost - ISNULL(a.Extra_winlost, 0) - ISNULL(a.scomm, 0) + ISNULL(a.Extra_comm, 0)) * actualrate ELSE 0 END) AS ourPT_won
				,SUM(CASE WHEN statusID = 113 THEN (company_winlost - ISNULL(a.Extra_winlost, 0) - ISNULL(a.scomm, 0) + ISNULL(a.Extra_comm, 0)) * actualrate ELSE 0 END) AS ourPT_lose		
				,ci.CustomerClass
			FROM dbo.rmSumWinloss a WITH (NOLOCK)
				INNER JOIN #tmpSelection s ON a.combo = s.selection
				INNER JOIN #tmpSport sp ON a.sporttype = sp.sporttype
				INNER JOIN #recommend r ON a.recommend = r.recommend
				INNER JOIN bodb02.dbo.CustInfo ci WITH(NOLOCK) ON a.custid = ci.custid
			WHERE a.winlostdate BETWEEN @f_date AND @t_date
				AND a.statusID IN (112, 113)
				AND a.currency <> 20
				AND ',' + @ParlayType + ',' LIKE '%,' + CONVERT(VARCHAR(5), a.ParlayType - 1) + ',%'
				AND (a.LiveIndicator = @LiveStatus OR @LiveStatus = 3)
			GROUP BY CONVERT(VARCHAR(7), winlostdate, 120), a.custid ,a.username, ci.CustomerClass
		END

		-- rmSumWinloss_Old
		IF @FromDate < @BalanceUpDay
		BEGIN
			SELECT	@f_date = @FromDate
					,@t_date = CASE WHEN @ToDate >= @BalanceUpDay THEN DATEADD(DAY, -1, @BalanceUpDay) ELSE @ToDate END

			INSERT INTO #tmpSum
			(
				month 
				,custid
				,username
				,tickets_won
				,tickets_lose 
				,stake_won 
				,stake_lose
				,member_won 
				,member_lose
				,ourPT_won 
				,ourPT_lose
				,CustomerClass
			)
			SELECT 
				CONVERT(VARCHAR(7), winlostdate, 120)
				,a.custid
				,a.username
				,SUM(CASE WHEN statusID = 112 THEN betcount ELSE 0 END) AS tickets_won
				,SUM(CASE WHEN statusID = 113 THEN betcount ELSE 0 END) AS tickets_lose
				,SUM(CASE WHEN statusID = 112 THEN company_stake*actualrate - ISNULL(a.Extra_stake, 0) * actualrate ELSE 0 END) AS stake_won
				,SUM(CASE WHEN statusID = 113 THEN company_stake*actualrate - ISNULL(a.Extra_stake, 0) * actualrate ELSE 0 END) AS stake_lose
				,SUM(CASE WHEN statusID = 112 THEN -(a.winlost-a.stake)*actualrate ELSE 0 END) AS member_won
				,SUM(CASE WHEN statusID = 113 THEN -(a.winlost-a.stake)*actualrate ELSE 0 END) AS member_lose
				,SUM(CASE WHEN statusID = 112 THEN (company_winlost - ISNULL(a.Extra_winlost, 0) - ISNULL(a.scomm, 0) + ISNULL(a.Extra_comm, 0)) * actualrate ELSE 0 END) AS ourPT_won
				,SUM(CASE WHEN statusID = 113 THEN (company_winlost - ISNULL(a.Extra_winlost, 0) - ISNULL(a.scomm, 0) + ISNULL(a.Extra_comm, 0)) * actualrate ELSE 0 END) AS ourPT_lose		
				,ci.CustomerClass
			FROM dbo.rmSumWinloss_Old a WITH (NOLOCK)
				INNER JOIN #tmpSelection s ON a.combo = s.selection
				INNER JOIN #tmpSport sp ON a.sporttype = sp.sporttype
				INNER JOIN #recommend r ON a.recommend = r.recommend
				INNER JOIN bodb02.dbo.CustInfo ci WITH(NOLOCK) ON a.custid = ci.custid
	
			WHERE a.winlostdate BETWEEN @f_date AND @t_date
				AND a.statusID IN (112, 113)
				AND a.currency <> 20
				AND ',' + @ParlayType + ',' LIKE '%,' + CONVERT(VARCHAR(5), a.ParlayType - 1) + ',%'
				AND (a.LiveIndicator = @LiveStatus OR @LiveStatus = 3)
			GROUP BY CONVERT(VARCHAR(7), winlostdate, 120), a.custid, a.username, ci.CustomerClass
		END
	END
	
	-- Return data
	SELECT b.month 
		,CASE WHEN s.isDeposit = 0 OR s.site = 'Saba789' THEN 'C' ELSE 'L' END SiteGroup
		,b.username
		,SUM(b.tickets_won)	AS tickets_won
		,SUM(b.tickets_lose)	AS tickets_lose
		,SUM(b.stake_won)		AS stake_won
		,SUM(b.stake_lose)	AS stake_lose
		,SUM(b.member_won)	AS member_won
		,SUM(b.member_lose)	AS member_lose
		,SUM(b.ourPT_won) AS ourPT_won
		,SUM(b.ourPT_lose)	AS ourPT_lose
		,b.CustomerClass
	FROM #tmpSum b
		LEFT JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON b.custid = c.custid
		LEFT JOIN bodb02.dbo.site s WITH(NOLOCK) ON c.site = s.site
	GROUP BY b.month, b.username, b.CustomerClass,
		CASE WHEN s.isDeposit = 0 OR s.site = 'Saba789' THEN 'C' ELSE 'L' END
	ORDER BY b.month, b.username

	DROP TABLE #bettype
	DROP TABLE #recommend
	DROP TABLE #tmpSelection
	DROP TABLE #tmpSport
	DROP TABLE #tmpSum
END
GO
