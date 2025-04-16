/*<info serverAlias="DBRMS-bodb_RMS" executers="wsv_rms" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[RMS_Rpt_ComboParlay_TopWinners]
	@fromdate		SMALLDATETIME,
	@todate			SMALLDATETIME,
	@movebetsday	DATETIME,
	@balanceUpday	DATETIME = NULL,
	@limitedRow		INT = 20,
	@sporttype		VARCHAR(100) = '',
	@selection		VARCHAR(MAX) = '',
	@ParlayType		VARCHAR(100) = '',
	@currency		VARCHAR(MAX) = '',
	@Site			TINYINT = 2,
	@CustomerClass	SMALLINT = NULL,
	@LiveStatus		TINYINT = 3,
	@Level			VARCHAR(100) = ''
AS

/*
	Created: 20160511@Winnie
	DB: DBRMS-bodb_RMS
	Task: Get top members won parlay

	Revisions:
		- 20170719@Winnie: Add MuayThai RedmineID: #79500
		- 20181010@Elodie: Enhance performance
		- 20180927@Jacob: Apply Extra PT and Super Comm to Report.  RedmineID: #100951 		
		- 20190214@Jacob: Add Bet Builder RedmineID: #108694
		- 20191211@Jacob: Extra PT - Add new structure to support extra pt column on bettrans table #124194
		- 20200510@Percy: Add Penalty Shootout Combo [RedmineID: #133961]
		- 20201204@Danny: Separate Data of Virtual Soccer & Virtual Basketball  [RedmineID: #145926]
		- 20210218@Danny: Monitor Performance of GOF  [RedmineID: #149966]
		- 20210303@Danny: Change on Report Top Winners [RedmineID: #146554]
		- 20210428@Danny: Add filtering by Site[RedmineID: #153874]
		- 20220519@Danny: add filter by Live Status [RedmineID: #172691]
		- 20230420@Cherry: Add Site column (#186735)
		- 20231020@Cherry: Parlay Generator (#195498)
		- 20231201@Cherry: Parlay Type for Parlay Boost (#197680)
		- 20240115@Cherry: Change attribute for Parlay Generator (#199766)
		- 20240312@Cherry: Change SQL account in metadata (#202012)
		- 20241204@Cherry: Add level (#212544)
		- 20241212@Cherry: Separate Cricket (#214664)
		- 20250410@Cherry: Upgrade ExchangeID (#222189)
	
	Parameter's Explanation:
		- @ParlayType:
					. 1: Mix parlay
					. 2: Combo parlay
					. 3: Single Match Parlay
					. 4: Panalty shootout combo
					. 5: GOF
					. 6: Parlay Generator
					. 7: Parlay Boost

		- @sporttype:
					. '1': soccer only
					. '-1': Combined other sports
					. '-2': Other sports
					. '-3': Combined sports
					. '-4': Saba soccer
					. '-5': Saba basketball
		
		- @level:
					. '0': none
					. '1,2,3': level 1,2,3
		
		 - @Site:
					. 0 = Credit sites
					. 1 = Deposit sites
					. 2 = All sites

*/

BEGIN
	SET NOCOUNT ON

	--Site
	BEGIN
		DECLARE @SiteTab TABLE (SiteName NVARCHAR(50), IsDeposit BIT)

		INSERT INTO @SiteTab(SiteName, IsDeposit)
		SELECT Site, CASE WHEN Site = 'Saba789'  THEN 0 ELSE isDeposit END
		FROM bodb02.dbo.Site (NOLOCK)
	END

	-- currency
	BEGIN
		CREATE TABLE #tmpCurrency (currency SMALLINT)
		INSERT INTO #tmpCurrency (currency)
		SELECT value FROM STRING_SPLIT(@currency, ',')

	END

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

	CREATE TABLE #tmpLevel (level INT)
	INSERT INTO #tmpLevel (level)
	SELECT DISTINCT val FROM dbo.f_RMS_strSplit(@Level, ',')

	-- sports
	BEGIN
		CREATE TABLE #tmpSport (sporttype INT)
		INSERT INTO #tmpSport (sporttype)
		SELECT value FROM STRING_SPLIT(@sporttype, ',')

		IF ',' + @sporttype + ',' LIKE '%,-2,%'
			INSERT INTO #tmpSport (sporttype)
			SELECT SportType FROM bodb02.dbo.Sports WITH (NOLOCK)
			WHERE SportType NOT IN (1,2,3,4,5,6,7,8,9,11,43,44,50)
				AND SportType <= 99
	END

	-- get data
	BEGIN
		CREATE TABLE #bettype (bettype SMALLINT)

		CREATE TABLE #ParlayType (ParlayType SMALLINT)

		INSERT INTO #ParlayType (ParlayType)
			SELECT	value
			FROM STRING_SPLIT(@ParlayType, ',') 

		IF EXISTS(SELECT TOP 1 1 FROM #ParlayType WHERE ParlayType = 1) 
		BEGIN
			IF NOT EXISTS(SELECT TOP 1 1 FROM #ParlayType WHERE ParlayType = 6)
				INSERT INTO #ParlayType (ParlayType) VALUES (6)
			IF NOT EXISTS(SELECT TOP 1 1 FROM #ParlayType WHERE ParlayType = 7)
				INSERT INTO #ParlayType (ParlayType) VALUES (7)
		END

		IF EXISTS(SELECT TOP 1 1 FROM #ParlayType WHERE ParlayType IN (6,7)) 
			INSERT INTO #ParlayType (ParlayType) VALUES (77) --Parlay Generator & Boost
	
		IF ',' + @ParlayType + ',' LIKE '%,1,%' OR ',' + @ParlayType + ',' LIKE '%,2,%' OR ',' + @ParlayType + ',' LIKE '%,5,%' OR ',' + @ParlayType + ',' LIKE '%,6,%' OR ',' + @ParlayType + ',' LIKE '%,7,%'
		BEGIN
			INSERT INTO #bettype (bettype)
			VALUES (29)
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

		CREATE TABLE #tmpBettrans (transid BIGINT, bac INT)

		CREATE TABLE #tmpSum
		(
			custid					INT
			,username				VARCHAR(30)
			,currency				INT
			,stake					MONEY
			,winlost				MONEY
			,company_winlost		MONEY
			,stake_baseRM			MONEY
			,winlost_baseRM			MONEY
			,company_winlost_baseRM	MONEY
			,betcount				INT
		)

		-- rmBettrans
		IF @ToDate > @MoveBetsDay
		BEGIN
			SELECT	@f_date = CASE WHEN @FromDate <= @MoveBetsDay THEN DATEADD(DAY, 1, @MoveBetsDay) ELSE @FromDate END
					,@t_date = @ToDate

			INSERT INTO #tmpBettrans (transid, bac)
			SELECT transid,
				ISNULL(TRY_CAST(TRY_CAST(ExtraInfo AS XML).value('(/p1/@bac)[1]', 'VARCHAR(50)') AS INT),0)
			FROM dbo.rmBettrans WITH (NOLOCK)				
			WHERE winlostdate BETWEEN @f_date AND @t_date
				AND statusID IN (112, 113)
				AND bettype = 29
				AND betteam = N'1'

			INSERT INTO #tmpSum
			(
				custid, username, currency, stake, winlost, company_winlost, stake_baseRM, winlost_baseRM, company_winlost_baseRM, betcount
			)
			SELECT b.custid, b.username, b.currency
				 ,SUM(stake)
				 ,SUM(winlost - actual_stake)
				 ,SUM(CASE WHEN 1 - tpositiontaking = 0 THEN 0  ELSE -(winlost - actual_stake) * (1 - tpositiontaking - CAST(ISNULL(epositiontaking, 0) AS DECIMAL(9,8))) - scomm  + scomm * CAST(ISNULL(epositiontaking, 0) AS DECIMAL(9,8)) / (1 - tpositiontaking) END)
				 ,SUM(stake * actualrate)
				 ,SUM((winlost - actual_stake) * actualrate)
				 ,SUM(CASE WHEN 1 - tpositiontaking = 0  THEN 0 ELSE (-(winlost - actual_stake) * (1 - tpositiontaking - CAST(ISNULL(epositiontaking, 0) AS DECIMAL(9,8))) - scomm  + scomm * CAST(ISNULL(epositiontaking, 0) AS DECIMAL(9,8)) / (1 - tpositiontaking)) * actualrate END)
				 ,COUNT(1)
			FROM dbo.rmBettrans b WITH (NOLOCK)				
				INNER JOIN #bettype bt ON b.bettype = bt.bettype
				INNER JOIN #tmpSelection s ON b.hdp2 = s.selection
				INNER JOIN #tmpSport sp ON b.transid2 = sp.sporttype
				INNER JOIN #tmpCurrency tc ON tc.currency = b.currency
				LEFT JOIN #tmpBettrans t ON b.transid = t.transid
				LEFT JOIN dbo.rmCustomer c WITH (NOLOCK) ON b.custid = c.custid			 
			WHERE winlostdate BETWEEN @f_date AND @t_date
				AND statusID IN (112, 113)
				AND (b.bettype <> 29
					OR (EXISTS(SELECT TOP 1 1 FROM #ParlayType WHERE ParlayType = 1)
						AND b.bettype = 29 AND b.betteam = N'1')
					OR (EXISTS(SELECT TOP 1 1 FROM #ParlayType WHERE ParlayType = 2)
						AND b.bettype = 29 AND b.betteam <> N'1')
					OR (EXISTS(SELECT TOP 1 1 FROM #ParlayType WHERE ParlayType = 5)
						AND b.bettype = 29 AND b.betteam = N'1' AND b.oddsspread = 1)
					OR (EXISTS(SELECT TOP 1 1 FROM #ParlayType WHERE ParlayType = 6)
						AND b.bettype = 29 AND b.betteam = N'1' AND t.bac|16 = t.bac)
					OR (EXISTS(SELECT TOP 1 1 FROM #ParlayType WHERE ParlayType = 7)
						AND b.bettype = 29 AND b.betteam = N'1' AND b.oddsspread = 2)
					)		
				AND (CASE WHEN b.bettype = 29 THEN b.livehomescore ELSE b.liveindicator END = @LiveStatus OR @LiveStatus = 3)
				AND ISNULL(c.level, 0) IN (SELECT level FROM #tmpLevel)
			GROUP BY b.custid, b.username, b.currency
		END

		-- rmSumWinloss
		IF @FromDate <= @MoveBetsDay AND @ToDate >= @BalanceUpDay
		BEGIN
			SELECT	@f_date = CASE WHEN @FromDate < @BalanceUpDay THEN @BalanceUpDay ELSE @FromDate END
					,@t_date = CASE WHEN @ToDate > @MoveBetsDay THEN @MoveBetsDay ELSE @ToDate END

			INSERT INTO #tmpSum
			(
				custid, username, currency, stake, winlost, company_winlost, stake_baseRM, winlost_baseRM, company_winlost_baseRM, betcount
			)
			SELECT a.custid, a.username, a.currency
				,SUM(stake)
				,SUM(winlost - stake)
				,SUM(company_winlost - ISNULL(a.extra_winlost, 0) - ISNULL(a.scomm, 0) + ISNULL(a.extra_comm, 0))
				,SUM(stake * actualrate)
				,SUM((winlost - stake) * actualrate)
				,SUM((company_winlost - ISNULL(a.extra_winlost, 0) - ISNULL(a.scomm, 0) + ISNULL(a.extra_comm, 0)) * actualrate)
				,SUM(betcount)
			FROM dbo.rmSumWinloss a WITH (NOLOCK)
				INNER JOIN #tmpSelection s ON a.combo = s.selection
				INNER JOIN #tmpSport sp ON a.sporttype = sp.sporttype
				INNER JOIN #tmpCurrency tc ON tc.currency = a.currency
				LEFT JOIN dbo.rmCustomer c WITH (NOLOCK) ON a.custid = c.custid
			WHERE a.winlostdate BETWEEN @f_date AND @t_date
				AND a.statusID IN (112, 113)
				AND EXISTS(SELECT TOP 1 1 FROM #ParlayType t WHERE a.parlaytype - 1 = t.ParlayType)
				AND (a.LiveIndicator = @LiveStatus OR @LiveStatus = 3)
				AND ISNULL(c.level, 0) IN (SELECT level FROM #tmpLevel)
			GROUP BY a.custid, a.username, a.currency
		END

		-- rmSumWinloss_Old
		IF @FromDate < @BalanceUpDay
		BEGIN
			SELECT	@f_date = @FromDate
					,@t_date = CASE WHEN @ToDate >= @BalanceUpDay THEN DATEADD(DAY, -1, @BalanceUpDay) ELSE @ToDate END

			INSERT INTO #tmpSum
			(
				custid, username, currency, stake, winlost, company_winlost, stake_baseRM, winlost_baseRM, company_winlost_baseRM, betcount
			)
			SELECT a.custid, a.username, a.currency
				,SUM(stake)
				,SUM(winlost - stake)
				,SUM(company_winlost - ISNULL(a.extra_winlost, 0) - ISNULL(a.scomm, 0) + ISNULL(a.extra_comm, 0))
				,SUM(stake * actualrate)
				,SUM((winlost - stake) * actualrate)
				,SUM((company_winlost - ISNULL(a.extra_winlost, 0) - ISNULL(a.scomm, 0) + ISNULL(a.extra_comm, 0)) * actualrate)
				,SUM(betcount)
			FROM dbo.rmSumWinloss_Old a WITH (NOLOCK)
				INNER JOIN #tmpSelection s ON a.combo = s.selection
				INNER JOIN #tmpSport sp ON a.sporttype = sp.sporttype
				INNER JOIN #tmpCurrency tc ON tc.currency = a.currency
				LEFT JOIN dbo.rmCustomer c WITH (NOLOCK) ON a.custid = c.custid
			WHERE a.winlostdate BETWEEN @f_date AND @t_date
				AND a.statusID IN (112, 113)
				AND EXISTS(SELECT TOP 1 1 FROM #ParlayType t WHERE a.parlaytype - 1 = t.ParlayType)
				AND (a.LiveIndicator = @LiveStatus OR @LiveStatus = 3)
				AND ISNULL(c.level, 0) IN (SELECT level FROM #tmpLevel)
			GROUP BY a.custid, a.username, a.currency
		END
	END

	-- Return data
	;WITH CTE_Result AS 
	(
		SELECT TOP (@limitedRow) r.custid, r.username, r.currency, ci.CustomerClass
			,SUM(stake)						AS stake
			,SUM(winlost)					AS winlost 
			,SUM(company_winlost)			AS company_winlost
			,SUM(stake_baseRM)				AS stake_baseRM
			,SUM(winlost_baseRM)			AS winlost_baseRM
			,SUM(company_winlost_baseRM)	AS company_winlost_baseRM
			,SUM(betcount)					AS betcount
			,SUM(winlost_baseRM) / SUM(stake_baseRM) AS avg_odds
		FROM #tmpSum r
		INNER JOIN bodb02.dbo.custInfo ci WITH(NOLOCK) ON r.custid = ci.custid
		INNER JOIN bodb02.dbo.Customer ct WITH(NOLOCK) ON r.custid = ct.custid
		WHERE (ci.CustomerClass = @CustomerClass OR @CustomerClass IS NULL)
			AND ct.Site IN (SELECT SiteName FROM @SiteTab WHERE IsDeposit = CASE WHEN @Site = 2 THEN IsDeposit ELSE @Site END)
		GROUP BY r.custid, r.username, r.currency, ci.CustomerClass
		HAVING SUM(winlost_baseRM) > 0
		ORDER BY SUM(winlost_baseRM) DESC
	)
	SELECT
		r.custid
		,CASE WHEN s.isDeposit = 0 OR s.site = 'Saba789' THEN 'C' ELSE 'L' END SiteGroup
		,r.username		
		,e.currency
		,stake
		,winlost
		,company_winlost
		,stake_baseRM
		,winlost_baseRM
		,company_winlost_baseRM
		,winlost_baseRM / stake_baseRM AS margin
		,betcount
		,avg_odds
		,ISNULL(rc.level, 0) AS level,
		r.CustomerClass
	FROM CTE_Result r
		INNER JOIN bodb02.dbo.Exchange e WITH (NOLOCK) ON r.currency = e.exchangeid
		LEFT JOIN rmCustomer rc WITH (NOLOCK) ON r.custid = rc.custid
		LEFT JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON r.custid = c.custid
		LEFT JOIN bodb02.dbo.site s WITH(NOLOCK) ON c.site = s.site	
	ORDER BY winlost_baseRM desc

	DROP TABLE #bettype
	DROP TABLE #tmpSelection
	DROP TABLE #tmpSport
	DROP TABLE #tmpSum
	DROP TABLE #tmpCurrency
	DROP TABLE #ParlayType
	DROP TABLE #tmpBettrans
	DROP TABLE #tmpLevel
END
GO