/*<info serverAlias="DBRMS-bodb_RMS" executers="wsv_rms" isFunction="0"></info>*/
 ALTER PROCEDURE [dbo].[RMS_Monitor_ComboParlay_PotentialWinningDetails]
	@CustID		INT,
	@selection	VARCHAR(MAX) = '',
	@sporttype	VARCHAR(100) = '',
	@ParlayType	VARCHAR(100)  = '',
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
		- 20201204@Danny: Separate Data of Virtual Soccer & Virtual Basketball  [RedmineID: #145926]
		- 20210218@Danny: Monitor Performance of GOF  [RedmineID: #149966]
		- 20210319@Danny: Incorporate Cricket AIO into PRMS [RedmineID: #151319]
		- 20210701@Danny: Track User Monitoring [RedmineID: #153875]
		- 20230320@Cherry: Change formula of Stake (#185251)
		- 20231020@Cherry: Parlay Generator (#195498)
		- 20240102@Cherry: Parlay Type for Parlay Boost (#199217)
		- 20240115@Cherry: Change attribute for Parlay Generator (#199766)
		- 20240312@Cherry: Change SQL account in metadata (#202012)
		- 20241212@Cherry: Separate Cricket (#214664)

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
					. '-4': Saba soccer
					. '-5': Saba basketball
		- @ParlayType:
					. 1: Mix parlay
					. 2: Combo parlay
					. 3: Single Match Parlay
					. 4: Panalty shootout combo
					. 5: GOF
					. 6: Parlay Generator
					. 7: Parlay Boost
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
			WHERE SportType NOT IN (1,2,3,4,5,6,7,8,9,11,43,44,50)
				AND SportType <= 99
	END

	-- get data
	BEGIN
		CREATE TABLE #bettype (bettype SMALLINT)

		CREATE TABLE #bettrans (
			refno BIGINT, 
			bettype SMALLINT, 
			transid BIGINT,
			CornerParlay	 INT DEFAULT(0),
			betteam	NVARCHAR(10),
			oddsspread SMALLMONEY,
			IsParlayGenerator BIT
		)

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
	END

	CREATE TABLE #Generator (transid BIGINT, bac INT)
	INSERT INTO #Generator(transid, bac)
	SELECT transid,
		TRY_CAST(TRY_CAST(ExtraInfo AS XML).value('(/p1/@bac)[1]', 'VARCHAR(50)') AS INT) 
	FROM dbo.rmBettrans WITH (NOLOCK)
	WHERE custid = @CustID
		AND statusID = 0
		AND currency <> 20
		AND bettype = 29
		AND betteam = N'1'

	INSERT INTO #bettrans (transid, bettype, refno, betteam, oddsspread, IsParlayGenerator)
	SELECT b.transid, b.bettype, b.refno, b.betteam, b.oddsspread,
		CAST(CASE WHEN b.bettype = 29 AND b.betteam = N'1' AND t.bac|16 = t.bac THEN 1 ELSE 0 END AS BIT)
	FROM dbo.rmBettrans b WITH (NOLOCK)
		INNER JOIN #bettype bt ON b.bettype = bt.bettype
		INNER JOIN #tmpSelection s ON b.hdp2 = s.selection
		INNER JOIN #tmpSport sp ON b.transid2 = sp.sporttype
		LEFT JOIN #Generator t ON b.transid = t.transid
	WHERE custid = @CustID
		AND b.statusID = 0
		AND b.currency <> 20
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

	CREATE CLUSTERED INDEX CIX_bettype ON #bettrans (bettype)

	CREATE TABLE #NumberWon (refno BIGINT, NumberWon INT, CornerParlay	 INT DEFAULT(0))

	IF EXISTS (SELECT 1 FROM #bettype WHERE bettype = 29)
		INSERT INTO #NumberWon (refno, NumberWon, CornerParlay)
		SELECT refno, SUM(ISNULL(bm.NumberWon, 0)), SUM (ISNULL(bm.CornerParlay,0))
		FROM #bettrans b
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
				UNION ALL
				SELECT	 SUM(CASE WHEN bm.statusID = 112 THEN 1 ELSE 0 END) as NumberWon,
						SUM(CASE WHEN m.ChildMatchType = 204 THEN 1 ELSE 0 END) AS CornerParlay
				FROM dbo.rmBettransm_bk bm WITH (NOLOCK)
				LEFT JOIN dbo.rmMatch_bk m WITH (NOLOCK) ON bm.matchid = m.matchid
				WHERE b.refno = bm.refno AND bm.winlostdate < @BalanceUpDay

			) bm
		WHERE bettype = 29
		GROUP BY refno

	-- filter by Corner Parlay Tickets
	IF @IsCornerParlay = 1 
	BEGIN
		DELETE b
		FROM #NumberWon b
		WHERE b.CornerParlay = 0
	END

	SELECT
		b.transdate
		,b.transid
		,b.refno
		,b.bettype
		,CASE WHEN transid2 NOT IN (-1,-3,1,2,3,4,5,6,7,8,9,11,43,44,-4,-5,50) THEN -2 ELSE transid2 END AS Sporttype
		,ISNULL(n.NumberWon, 0) AS NumberWon
		,b.odds2 * b.TotalBet AS odds
		,b.stake * b.actualrate AS Stake
		,(b.odds2 - 1) * b.stake * b.actualrate AS WinningAmount
		,(b.odds2 - 1) * b.stake * b.actualrate * (1 - b.tpositiontaking) AS CompanyLoseAmount
		,b.ip
		,(1 - b.tpositiontaking) AS HousePT
		,b.hdp2 AS TotalSelection
		,b.TotalBet AS TotalBet
		,CAST(CASE WHEN b.bettype = 29 AND b.betteam= N'1' AND b.oddsspread = 1 THEN 1 ELSE 0 END AS BIT) AS IsGOF
		,rb.IsParlayGenerator
		,CAST(CASE WHEN b.bettype = 29 AND b.betteam= N'1' AND b.oddsspread = 2 THEN 1 ELSE 0 END AS BIT) AS IsBoostBonus
		,l.username AS TrackingUser
	FROM dbo.rmBettrans b WITH (NOLOCK)
		INNER JOIN #bettrans rb ON rb.transid = b.transid
		LEFT JOIN #NumberWon n ON b.refno = n.refno
		LEFT JOIN dbo.rmUserTrackingLog l WITH(NOLOCK) ON b.transid = l.transid
	ORDER BY b.transdate DESC

	DROP TABLE #bettrans
	DROP TABLE #bettype
	DROP TABLE #NumberWon
	DROP TABLE #tmpSelection
	DROP TABLE #tmpSport
	DROP TABLE #ParlayType
	DROP TABLE #Generator
END
GO