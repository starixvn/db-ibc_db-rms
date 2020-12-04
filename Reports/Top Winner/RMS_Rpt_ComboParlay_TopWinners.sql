/*<info serverAlias="DBRMS-bodb_RMS" executers="bodbRMSNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[RMS_Rpt_ComboParlay_TopWinners]
	@fromdate		SMALLDATETIME,
	@todate			SMALLDATETIME,
	@movebetsday	DATETIME,
	@balanceUpday	DATETIME = NULL,
	@limitedRow		INT = 20,
	@sporttype		VARCHAR(100) = '',
	@selection		VARCHAR(MAX) = '',
	@ParlayType		VARCHAR(20) = ''
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
	
	Parameter's Explanation:
		- @ParlayType:
					. 1: Mix parlay
					. 2: Combo parlay
					. 3: Single Match Parlay
					. 4: Panalty shootout combo
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
			SELECT val FROM dbo.f_RMS_strSplit(@selection, ',')
		END
		-- 10UP (add 11 --> 100)
		ELSE IF ',' + @selection + ',' LIKE '%,10,%'
		BEGIN
			SELECT @selection = @selection + ',11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,64,65,66,67,68,69,70,71,72,73,74,75,76,77,78,79,80,81,82,83,84,85,86,87,88,89,90,91,92,93,94,95,96,97,98,99,100'
		
			INSERT INTO #tmpSelection (selection)
			SELECT val FROM dbo.f_RMS_strSplit(@selection, ',')
		END
		ELSE
		BEGIN
			INSERT INTO #tmpSelection (selection)
			SELECT val FROM dbo.f_RMS_strSplit(@selection, ',')
		END
	END

	-- sports
	BEGIN
		CREATE TABLE #tmpSport (sporttype INT)
		INSERT INTO #tmpSport (sporttype)
		SELECT val FROM dbo.f_RMS_strSplit(@sporttype, ',')

		IF ',' + @sporttype + ',' LIKE '%,-2,%'
			INSERT INTO #tmpSport (sporttype)
			SELECT SportType FROM bodb02.dbo.Sports WITH (NOLOCK)
			WHERE SportType NOT IN (1,2,3,4,5,6,7,8,9,11,43,44)
				AND SportType <= 99
	END

	-- get data
	BEGIN
		CREATE TABLE #bettype (bettype SMALLINT)

		-- Combo parlay
		DECLARE @ComboType TINYINT = 0 -- 1: mix parlay only, 2: combo parlay only, 3: combined
		
		IF ',' + @ParlayType + ',' LIKE '%,1,%' OR ',' + @ParlayType + ',' LIKE '%,2,%'
		BEGIN
			INSERT INTO #bettype (bettype)
			VALUES (29)

			IF (SELECT COUNT(DISTINCT val) FROM dbo.f_RMS_strSplit(@ParlayType, ',') WHERE val IN (1,2)) = 2
				SELECT @ComboType = 3
			ELSE IF ',' + @ParlayType + ',' LIKE '%,1,%'
				SELECT @ComboType = 1
			ELSE
				SELECT @ComboType = 2
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

			INSERT INTO #tmpSum
			(
				custid, username, currency, stake, winlost, company_winlost, stake_baseRM, winlost_baseRM, company_winlost_baseRM, betcount
			)
			SELECT custid, username, currency
				 ,SUM(stake)
				 ,SUM(winlost - actual_stake)
				 ,SUM(-(winlost - actual_stake) * (1 - tpositiontaking - CAST(ISNULL(epositiontaking, 0) AS DECIMAL(9,8))) - scomm  + scomm * CAST(ISNULL(epositiontaking, 0) AS DECIMAL(9,8)) / (1 - tpositiontaking))
				 ,SUM(stake * actualrate)
				 ,SUM((winlost - actual_stake) * actualrate)
				 ,SUM((-(winlost - actual_stake) * (1 - tpositiontaking - CAST(ISNULL(epositiontaking, 0) AS DECIMAL(9,8))) - scomm  + scomm * CAST(ISNULL(epositiontaking, 0) AS DECIMAL(9,8)) / (1 - tpositiontaking)) * actualrate)
				 ,COUNT(1)
			FROM dbo.rmBettrans_uat b WITH (NOLOCK)
				INNER JOIN #bettype bt ON b.bettype = bt.bettype
				INNER JOIN #tmpSelection s ON b.hdp2 = s.selection
				INNER JOIN #tmpSport sp ON b.transid2 = sp.sporttype
			WHERE winlostdate BETWEEN @f_date AND @t_date
				AND statusID IN (112, 113)
				AND 1 = CASE
							WHEN b.bettype = 29 AND @ComboType IN (1, 2) THEN CASE
								WHEN @ComboType = 1 AND b.betteam = N'1' THEN 1
								WHEN @ComboType = 2 AND b.betteam <> N'1' THEN 1
								ELSE 0 END
							ELSE 1 END
			GROUP BY custid, username, currency
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
			SELECT custid, username, currency
				,SUM(stake)
				,SUM(winlost - stake)
				,SUM(company_winlost - ISNULL(a.extra_winlost, 0) - ISNULL(a.scomm, 0) + ISNULL(a.extra_comm, 0))
				,SUM(stake * actualrate)
				,SUM((winlost - stake) * actualrate)
				,SUM((company_winlost - ISNULL(a.extra_winlost, 0) - ISNULL(a.scomm, 0) + ISNULL(a.extra_comm, 0)) * actualrate)
				,SUM(betcount)
			FROM dbo.rmSumWinloss_uat a WITH (NOLOCK)
				INNER JOIN #tmpSelection s ON a.combo = s.selection
				INNER JOIN #tmpSport sp ON a.sporttype = sp.sporttype
			WHERE a.winlostdate BETWEEN @f_date AND @t_date
				AND a.statusID IN (112, 113)
				AND ',' + @ParlayType + ',' LIKE '%,' + CONVERT(VARCHAR(5), a.ParlayType - 1) + ',%'
			GROUP BY custid, username, currency
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
			SELECT custid, username, currency
				,SUM(stake)
				,SUM(winlost - stake)
				,SUM(company_winlost - ISNULL(a.extra_winlost, 0) - ISNULL(a.scomm, 0) + ISNULL(a.extra_comm, 0))
				,SUM(stake * actualrate)
				,SUM((winlost - stake) * actualrate)
				,SUM((company_winlost - ISNULL(a.extra_winlost, 0) - ISNULL(a.scomm, 0) + ISNULL(a.extra_comm, 0)) * actualrate)
				,SUM(betcount)
			FROM dbo.rmSumWinloss_Old_uat a WITH (NOLOCK)
				INNER JOIN #tmpSelection s ON a.combo = s.selection
				INNER JOIN #tmpSport sp ON a.sporttype = sp.sporttype
			WHERE a.winlostdate BETWEEN @f_date AND @t_date
				AND a.statusID IN (112, 113)
				AND ',' + @ParlayType + ',' LIKE '%,' + CONVERT(VARCHAR(5), a.ParlayType - 1) + ',%'
			GROUP BY custid, username, currency
		END
	END

	-- Return data
	;WITH CTE_Result AS 
	(
		SELECT TOP (@limitedRow) custid, username, currency
			,SUM(stake)						AS stake
			,SUM(winlost)					AS winlost 
			,SUM(company_winlost)			AS company_winlost
			,SUM(stake_baseRM)				AS stake_baseRM
			,SUM(winlost_baseRM)			AS winlost_baseRM
			,SUM(company_winlost_baseRM)	AS company_winlost_baseRM
			,SUM(betcount)					AS betcount
			,SUM(winlost_baseRM) / SUM(stake_baseRM) AS avg_odds
		FROM #tmpSum		
		GROUP BY custid, username, currency
		HAVING SUM(winlost_baseRM) > 0
		ORDER BY SUM(winlost_baseRM) DESC
	)
	SELECT
		r.custid
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
		,ISNULL(c.level, 0) AS level
	FROM CTE_Result r
		INNER JOIN bodb02.dbo.Exchange e WITH (NOLOCK) ON r.currency = e.exchangeid
		LEFT JOIN rmCustomer c WITH (NOLOCK) ON r.custid = c.custid

	DROP TABLE #bettype
	DROP TABLE #tmpSelection
	DROP TABLE #tmpSport
	DROP TABLE #tmpSum
END
GO