/*<info serverAlias="DBRMS-bodb_RMS" executers="wsv_rms" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[RMS_Rpt_ComboParlay_Outstanding_Mem]
	@custid		INT,	
	@selection	VARCHAR(MAX) = '',
	@sporttype	VARCHAR(100) = '',
	@ParlayType	VARCHAR(100)='',
	@IsCornerParlay BIT = 0
AS

/*
	Created: 20160426@Winnie
	DB: DBRMS-bodb_RMS
	Task: Get combo parlay betlist running by member
		
	Revisions:		
		- 20170719@Winnie: Add MuayThai RedmineID: #79500
		- 20190214@Jacob: Add Bet Builder RedmineID: #108694
		- 20200510@Percy: Add Penalty Shootout Combo [RedmineID: #133961]
		- 20201211@Danny: Monitor Corner Parlay Tickets [RedmineID: #146929]
		- 20201204@Danny: Separate Data of Virtual Soccer & Virtual Basketball  [RedmineID: #145926]
		- 20210218@Danny: Monitor Performance of GOF  [RedmineID: #149966]
		- 20210303@Danny: Correct data bettransm14  [RedmineID: #148137]
		- 20210628@Danny: Add Column Member Potential Winning [RedmineID: #156979]
		- 20210629@Danny: Add filtering by Customer Class[RedmineID: #156980]
		- 20230320@Cherry: Change formula of Stake (#185251)
		- 20231020@Cherry: Parlay Generator (#195498)
		- 20240102@Cherry: Parlay Type for Parlay Boost (#199217)
		- 20240115@Cherry: Change attribute for Parlay Generator (#199766)
		- 20240312@Cherry: Change SQL account in metadata (#202012)
		- 20241212@Cherry: Separate Cricket (#214664)
		- 20251020@Cherry: Integrate Hybrid Parlay (#242165)
		
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
					. -4: saba soccer
					. -5: saba basketball

		- @ParlayType:
					. 1: Mix parlay
					. 2: Combo parlay
					. 3: Single Match Parlay
					. 4: Panalty shootout combo
					. 5: GOF
					. 6: Parlay Generator
					. 7: Parlay Boost
					. 8: Hybrid Parlay
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
			WHERE SportType NOT IN (1,2,3,4,5,6,7,8,9,11,43,44,50)
				AND SportType <= 99
	END

	-- get data
	BEGIN
		CREATE TABLE #bettrans
		(
			transid		BIGINT
			,refno		BIGINT
			,matchid	INT
			,bettype	SMALLINT
			,market		TINYINT -- 1: today only, 2: early only, 3: combined
			,NumberWon	INT DEFAULT(0)
			,CornerParlay	 INT DEFAULT(0)
			,betteam	NVARCHAR(10)
			,oddsspread SMALLMONEY
			,bac		INT
		)

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
	
		IF ',' + @ParlayType + ',' LIKE '%,1,%' OR ',' + @ParlayType + ',' LIKE '%,2,%' OR ',' + @ParlayType + ',' LIKE '%,5,%' OR ',' + @ParlayType + ',' LIKE '%,6,%' OR ',' + @ParlayType + ',' LIKE '%,7,%' OR ',' + @ParlayType + ',' LIKE '%,8,%'
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

		CREATE TABLE #Generator (transid BIGINT, bac INT)
		INSERT INTO #Generator (transid, bac)
		SELECT transid,
			ISNULL(TRY_CAST(TRY_CAST(ExtraInfo AS XML).value('(/p1/@bac)[1]', 'VARCHAR(50)') AS INT),0)
		FROM dbo.rmBettrans WITH (NOLOCK)
		WHERE statusID = 0
			AND custid = @custid
			AND bettype = 29
			AND betteam = N'1'

		INSERT INTO #bettrans (transid, bettype, refno, betteam, oddsspread, bac)
		SELECT b.transid, b.bettype, b.refno, b.betteam, b.oddsspread, t.bac
		FROM dbo.rmBettrans b WITH (NOLOCK)
			INNER JOIN #bettype bt ON b.bettype = bt.bettype
			INNER JOIN #tmpSelection s ON b.hdp2 = s.selection
			INNER JOIN #tmpSport sp ON b.transid2 = sp.sporttype
			LEFT JOIN #Generator t ON b.transid = t.transid
		WHERE b.statusID = 0
			AND b.custid = @custid
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
				OR (EXISTS(SELECT TOP 1 1 FROM #ParlayType WHERE ParlayType = 8)
					AND b.bettype = 29 AND b.betteam = N'1' AND b.oddsspread = 3)
				)		

		DROP TABLE #bettype
		DROP TABLE #tmpSelection
		DROP TABLE #tmpSport

		CREATE CLUSTERED INDEX CIX_bettype ON #bettrans (bettype)

		IF EXISTS (SELECT 1 FROM #bettrans WHERE bettype = 29)
		BEGIN
			UPDATE b
			SET b.NumberWon = ISNULL(b.NumberWon, 0) + ISNULL(bm.NumberWon,0),
				b.CornerParlay = ISNULL(b.CornerParlay, 0) +  ISNULL(bm.CornerParlay,0)
			FROM #bettrans b
				CROSS APPLY (
					SELECT	SUM(CASE WHEN bm.statusID = 112 THEN 1 ELSE 0 END) NumberWon,
							SUM(CASE WHEN m.ChildMatchType = 204 THEN 1 ELSE 0 END) AS CornerParlay
					FROM bodb02.dbo.bettransm bm WITH (NOLOCK)
					LEFT JOIN bodb02.dbo.match m WITH (NOLOCK) ON bm.matchid = m.matchid
					WHERE b.refno = bm.refno 
				) bm
			WHERE b.bettype = 29

			UPDATE b
			SET b.NumberWon = ISNULL(b.NumberWon, 0) + ISNULL(bm.NumberWon,0),
				b.CornerParlay = ISNULL(b.CornerParlay, 0) +  ISNULL(bm.CornerParlay,0)
			FROM #bettrans b
				CROSS APPLY (
					SELECT  SUM(CASE WHEN bm.statusID = 112 THEN 1 ELSE 0 END) NumberWon,
							SUM(CASE WHEN m.ChildMatchType = 204 THEN 1 ELSE 0 END) AS CornerParlay
					FROM bodb02.dbo.bettransm14 bm WITH (NOLOCK)
					LEFT JOIN bodb02.dbo.match14 m WITH (NOLOCK) ON bm.matchid = m.matchid
					WHERE b.refno = bm.refno 
				) bm
			WHERE b.bettype = 29
		END

		-- filter by Corner Parlay Tickets
		IF @IsCornerParlay = 1 
		BEGIN
			DELETE b
			FROM #bettrans b
			WHERE b.CornerParlay = 0
		END		
		
	END

	-- Return data
	BEGIN
		SELECT
			rb.transid
			,rb.refno
			,rb.bettype
			,rb.transdate
			,rb.odds2 * rb.TotalBet AS odds
			,rb.stake * rb.actualrate / rb.TotalBet AS stake
			,rb.stake * rb.actualrate AS stakePT
			,rb.stake * rb.actualrate * (rb.odds2 - 1) * (1 - rb.tpositiontaking) AS net_win
			,rb.hdp2 AS TotalSelection
			,ISNULL(b.NumberWon, 0) AS NumberWon
			,rb.TotalBet AS TotalBet
			,CASE WHEN rb.transid2 NOT IN (-1,-3,1,2,3,4,5,6,7,8,9,11,43,44,-4,-5,50) THEN -2 ELSE rb.transid2 END AS Sporttype
			,CAST(CASE WHEN rb.bettype = 29 AND rb.betteam = N'1' AND rb.oddsspread = 1 THEN 1 ELSE 0 END AS BIT) AS IsGOF
			,CASE WHEN b.bac|16 = b.bac THEN 1 ELSE 0 END AS IsParlayGenerator
			,CAST(CASE WHEN rb.bettype = 29 AND rb.betteam = N'1' AND rb.oddsspread = 2 THEN 1 ELSE 0 END AS BIT) AS IsBoostBonus
			,(rb.odds2 - 1) * rb.stake * rb.actualrate  AS potentialWinningAmt
			,ci.CustomerClass
		FROM rmBettrans rb WITH(NOLOCK)
			INNER JOIN #bettrans b ON rb.transid = b.transid
			INNER JOIN bodb02.dbo.custInfo ci WITH(NOLOCK) ON ci.custID = rb.custid
		ORDER BY net_win DESC
	END

	DROP TABLE #bettrans
	DROP TABLE #ParlayType
	DROP TABLE #Generator
END
GO