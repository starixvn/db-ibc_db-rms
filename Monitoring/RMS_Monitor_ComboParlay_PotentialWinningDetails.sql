/*<info serverAlias="DBRMS-bodb_RMS" executers="bodbRMSNet" isFunction="0"></info>*/
 ALTER PROCEDURE [dbo].[RMS_Monitor_ComboParlay_PotentialWinningDetails]
	@CustID		INT,
	@selection	VARCHAR(MAX) = '',
	@sporttype	VARCHAR(100) = '',
	@ParlayType	VARCHAR(10)  = '',
	@IsCornerParlay BIT = 0
AS

/*	
	Created: 20160427@Winnie
	DB: DBRMS-bodb_RMS
	Task: Get detail report of Potential Winning Tool

	Revisions:
		- 20170719@Winnie: Add MuayThai RedmineID: #79500
		- 20190214@Jacob: Add Bet Builder RedmineID: #108694
		- 20200510@Percy: Add Penalty Shootout Combo [RedmineID: #133961]
		- 20200821@Percy: Fix issue duplicate data due to MBBU process [RedmineID: #140078]
		- 20201211@Danny: Monitor Corner Parlay Tickets [RedmineID: #146929]

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
		- @ParlayType:
					. 1: Mix parlay
					. 2: Combo parlay
					. 3: Single Match Parlay
					. 4: Panalty shootout combo
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @MBU TABLE (BalanceUpDay SMALLDATETIME, MoveBetsDay SMALLDATETIME)
	INSERT INTO @MBU (BalanceUpDay, MoveBetsDay)
	EXEC bodb02.dbo.Age_SelBalanceUpDay

	DECLARE @BalanceUpDay SMALLDATETIME, @MoveBetsDay SMALLDATETIME
	SELECT  @BalanceUpDay = BalanceUpDay, @MoveBetsDay = MoveBetsDay FROM @MBU

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
	END

	CREATE TABLE #NumberWon (refno BIGINT, NumberWon INT, CornerParlay	 INT DEFAULT(0))

	IF EXISTS (SELECT 1 FROM #bettype WHERE bettype = 29)
		INSERT INTO #NumberWon (refno, NumberWon, CornerParlay)
		SELECT refno, SUM(ISNULL(bm.NumberWon, 0)), SUM (ISNULL(bm.CornerParlay,0))
		FROM dbo.rmBettrans b WITH (NOLOCK)
			CROSS APPLY (
				SELECT	SUM(CASE WHEN bm.statusID = 112 THEN 1 ELSE 0 END) as NumberWon,
						SUM(CASE WHEN m.ChildMatchType = 204 THEN 1 ELSE 0 END) AS CornerParlay
				FROM bodb02.dbo.bettransm bm WITH (NOLOCK)
				LEFT JOIN bodb02.dbo.match m WITH (NOLOCK) ON bm.matchid = m.matchid
				WHERE b.refno = bm.refno AND bm.winlostdate > @MoveBetsDay
				UNION ALL
				SELECT	 SUM(CASE WHEN bm.statusID = 112 THEN 1 ELSE 0 END) as NumberWon,
						SUM(CASE WHEN m.ChildMatchType = 204 THEN 1 ELSE 0 END) AS CornerParlay
				FROM bodb02.dbo.bettransm14 bm WITH (NOLOCK)
				LEFT JOIN bodb02.dbo.match14 m WITH (NOLOCK) ON bm.matchid = m.matchid
				WHERE b.refno = bm.refno AND bm.winlostdate BETWEEN @BalanceUpDay AND @MoveBetsDay
			) bm
		WHERE custid = @CustID
			AND statusID = 0
			AND bettype = 29
		GROUP BY refno
	
	IF @IsCornerParlay = 0  
	BEGIN
		SELECT
			b.transdate
			,b.transid
			,b.refno
			,b.bettype
			,CASE WHEN transid2 NOT IN (-1,-3,1,2,3,4,5,6,7,8,9,11,43,44) THEN -2 ELSE transid2 END AS Sporttype
			,ISNULL(n.NumberWon, 0) AS NumberWon
			,b.odds2 * b.TotalBet AS odds
			,b.stake * b.actualrate / b.TotalBet AS Stake
			,(b.odds2 - 1) * b.stake * b.actualrate AS WinningAmount
			,(b.odds2 - 1) * b.stake * b.actualrate * (1 - b.tpositiontaking) AS CompanyLoseAmount
			,b.ip
			,(1 - b.tpositiontaking) AS HousePT
			,b.hdp2 AS TotalSelection
			,b.TotalBet AS TotalBet
		FROM dbo.rmBettrans b WITH (NOLOCK)
			INNER JOIN #bettype bt ON b.bettype = bt.bettype
			INNER JOIN #tmpSelection s ON b.hdp2 = s.selection
			INNER JOIN #tmpSport sp ON b.transid2 = sp.sporttype
			LEFT JOIN #NumberWon n ON b.refno = n.refno
		WHERE b.custid = @CustID
			AND b.statusID = 0
			AND currency <> 20
			AND 1 = CASE
						WHEN b.bettype = 29 AND @ComboType IN (1, 2) THEN CASE
							WHEN @ComboType = 1 AND b.betteam = N'1' THEN 1
							WHEN @ComboType = 2 AND b.betteam <> N'1' THEN 1
							ELSE 0 END
						ELSE 1 END

		ORDER BY b.transdate DESC
	END 
	ELSE 
	BEGIN
		SELECT
			b.transdate
			,b.transid
			,b.refno
			,b.bettype
			,CASE WHEN transid2 NOT IN (-1,-3,1,2,3,4,5,6,7,8,9,11,43,44) THEN -2 ELSE transid2 END AS Sporttype
			,ISNULL(n.NumberWon, 0) AS NumberWon
			,b.odds2 * b.TotalBet AS odds
			,b.stake * b.actualrate / b.TotalBet AS Stake
			,(b.odds2 - 1) * b.stake * b.actualrate AS WinningAmount
			,(b.odds2 - 1) * b.stake * b.actualrate * (1 - b.tpositiontaking) AS CompanyLoseAmount
			,b.ip
			,(1 - b.tpositiontaking) AS HousePT
			,b.hdp2 AS TotalSelection
			,b.TotalBet AS TotalBet
		FROM dbo.rmBettrans b WITH (NOLOCK)
			INNER JOIN #bettype bt ON b.bettype = bt.bettype
			INNER JOIN #tmpSelection s ON b.hdp2 = s.selection
			INNER JOIN #tmpSport sp ON b.transid2 = sp.sporttype
			INNER JOIN #NumberWon n ON b.refno = n.refno and n.CornerParlay > 0
		WHERE b.custid = @CustID
			AND b.statusID = 0
			AND currency <> 20
			AND 1 = CASE
						WHEN b.bettype = 29 AND @ComboType IN (1, 2) THEN CASE
							WHEN @ComboType = 1 AND b.betteam = N'1' THEN 1
							WHEN @ComboType = 2 AND b.betteam <> N'1' THEN 1
							ELSE 0 END
						ELSE 1 END

		ORDER BY b.transdate DESC
	END

	DROP TABLE #bettype
	DROP TABLE #NumberWon
	DROP TABLE #tmpSelection
	DROP TABLE #tmpSport
END
GO