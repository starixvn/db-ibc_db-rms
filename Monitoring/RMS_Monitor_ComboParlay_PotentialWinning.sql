/*<info serverAlias="DBRMS-bodb_RMS" executers="bodbRMSNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[RMS_Monitor_ComboParlay_PotentialWinning]
	@selection		VARCHAR(MAX) = '',
	@sporttype		VARCHAR(100) = '',
	@level			VARCHAR(100) = '',
	@WinningAmount	MONEY = 0,
	@limitRowCount	INT = 100,
	@ParlayType		VARCHAR(10)  = '',
	@IsCornerParlay BIT = 0
AS

/*
	Created: 20160427@Winnie
	DB: DBRMS-bodb_RMS
	Task: Monitoring Total Potential Winning by member

	Revisions:
		- 20170719@Winnie: Add MuayThai RedmineID: #79500
		- 20171219@Vicky: Add column currency [RedmineID: #88400]
		- 20190214@Jacob: Add Bet Builder RedmineID: #108694
		- 20200510@Percy: Add Penalty Shootout Combo [RedmineID: #133961]
		- 20201211@Danny: Monitor Corner Parlay Tickets [RedmineID: #146929]
		- 20201226@Sophia: Workaround for performance issue [RedmineID: #146929] 

	Parameter's Explanation:
		- @selection:
					. '2,3': 2,3 selections
					. '10': 10 UP
					. '0' : All
		- @sporttype:
					. '1': soccer only
					. '-1': Combined other sports
					. '-2': Other sports
					. '-3': Combined sports
		- @level:
					. '0': none
					. '1,2,3': level 1,2,3
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
		CREATE TABLE #bettrans (
			refno BIGINT, 
			bettype SMALLINT, 
			transid BIGINT,
			CornerParlay	 INT DEFAULT(0)
		)

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

		INSERT INTO #bettrans (transid, bettype, refno)
		SELECT b.transid, b.bettype, b.refno
		FROM dbo.rmBettrans b WITH (NOLOCK)
			INNER JOIN #bettype bt ON b.bettype = bt.bettype
			INNER JOIN #tmpSelection s ON b.hdp2 = s.selection
			INNER JOIN #tmpSport sp ON b.transid2 = sp.sporttype
		WHERE b.statusID = 0
			AND b.currency <> 20
		
		CREATE CLUSTERED INDEX CIX_bettype ON #bettrans (bettype)

		IF EXISTS (SELECT 1 FROM #bettrans WHERE bettype = 29)
		BEGIN
			UPDATE b
			SET 
				b.CornerParlay = ISNULL(b.CornerParlay, 0) + ISNULL(bm.CornerParlay,0)
			FROM #bettrans b
				INNER JOIN (
					SELECT	bm.refno, 
							SUM(CASE WHEN bm.statusID = 112 THEN 1 ELSE 0 END) NumberWon,
							SUM(CASE WHEN m.ChildMatchType = 204 THEN 1 ELSE 0 END) AS CornerParlay
					FROM bodb02.dbo.bettransm bm WITH (NOLOCK)
					LEFT JOIN bodb02.dbo.match m WITH (NOLOCK) ON bm.matchid = m.matchid
					GROUP BY bm.refno					
				) bm ON b.refno = bm.refno 
			WHERE b.bettype = 29

			UPDATE b
			SET b.CornerParlay = ISNULL(b.CornerParlay, 0) +  ISNULL(bm.CornerParlay,0)
			FROM #bettrans b
				INNER JOIN (
					SELECT  bm.refno,
							SUM(CASE WHEN bm.statusID = 112 THEN 1 ELSE 0 END) NumberWon,
							SUM(CASE WHEN m.ChildMatchType = 204 THEN 1 ELSE 0 END) AS CornerParlay
					FROM bodb02.dbo.bettransm14 bm WITH (NOLOCK)
					LEFT JOIN bodb02.dbo.match14 m WITH (NOLOCK) ON bm.matchid = m.matchid
					WHERE bm.statusID = 112
					GROUP BY bm.refno
				) bm ON b.refno = bm.refno
			WHERE b.bettype = 29
		END


		-- filter by Corner Parlay Tickets
	
		IF @IsCornerParlay = 1 
		BEGIN
			DELETE b
			FROM #bettrans b
			WHERE b.CornerParlay = 0
		END

		DROP TABLE #bettype
		DROP TABLE #tmpSelection
		DROP TABLE #tmpSport
		
	END

	-- Return data
	BEGIN
		CREATE TABLE #level (level TINYINT)
		INSERT INTO #level (level)
		SELECT DISTINCT val FROM dbo.f_RMS_strSplit(@level, ',')

		SELECT TOP (@limitRowcount)
			MAX(rb.transdate) AS transdate
			,rb.custid
			,rb.username
			,AVG(rb.odds2 * rb.TotalBet) AS Odds
			,SUM(rb.stake * rb.actualrate) AS stake
			,SUM((rb.odds2 - 1) * rb.stake * rb.actualrate) AS WinningAmount
			,SUM((rb.odds2 - 1) * rb.stake * rb.actualrate * (1 - rb.tpositiontaking)) AS CompanyLoseAmount
			,COUNT(1) AS TotalBets
			,ISNULL(mc.level, 0) AS level
			,rb.CurrencyName AS currency
		FROM dbo.rmBettrans rb WITH(NOLOCK) 
			INNER JOIN #bettrans b ON rb.transid = b.transid
			LEFT JOIN rmCustomer mc WITH (NOLOCK) ON rb.custid = mc.custid
		WHERE
			ISNULL(mc.level, 0) IN (SELECT level FROM #level)
			AND 1 = CASE
						WHEN rb.bettype = 29 AND @ComboType IN (1, 2) THEN CASE
							WHEN @ComboType = 1 AND rb.betteam = N'1' THEN 1
							WHEN @ComboType = 2 AND rb.betteam <> N'1' THEN 1
							ELSE 0 END
						ELSE 1 END
		GROUP BY
			rb.custid
			,rb.username 
			,ISNULL(mc.level, 0)
			,rb.CurrencyName
		HAVING SUM((rb.odds2 - 1) * rb.stake * rb.actualrate) >= @WinningAmount
		ORDER BY WinningAmount DESC
	END
	
	DROP TABLE #bettrans
END
GO