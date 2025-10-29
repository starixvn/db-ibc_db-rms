/*<info serverAlias="DBRMS-bodb_RMS" executers="wsv_rms" isFunction="0" isNested="0"></info>*/
 ALTER PROCEDURE [dbo].[RMS_Rpt_ComboParlay_Outstanding_Ag]
	@custid		INT,	
	@selection	VARCHAR(MAX) = '',
	@sporttype	VARCHAR(100) = '',
	@ParlayType	VARCHAR(100)='',
	@IsCornerParlay BIT = 0
AS

/*
	Created: 20160427@Winnie
	DB: DBRMS-bodb_RMS
	Task: Get combo parlay betlist running by agent
		
		
	Revisions:
		- 20170719@Winnie: Add MuayThai RedmineID: #79500
		- 20190214@Jacob: Add Bet Builder RedmineID: #108694
		- 20200510@Percy: Add Penalty Shootout Combo [RedmineID: #133961]
		- 20201211@Danny: Monitor Corner Parlay Tickets [RedmineID: #146929]
		- 20201204@Danny: Separate Data of Virtual Soccer & Virtual Basketball  [RedmineID: #145926]
		- 20210218@Danny: Monitor Performance of GOF  [RedmineID: #149966]
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
	END

	CREATE TABLE #Generator (transid BIGINT, bac INT)
	INSERT INTO #Generator (transid, bac)
	SELECT transid,
		ISNULL(TRY_CAST(TRY_CAST(ExtraInfo AS XML).value('(/p1/@bac)[1]', 'VARCHAR(50)') AS INT),0)
	FROM rmBettrans WITH (NOLOCK)
	WHERE recommend = @custid
		AND statusid = 0
		AND bettype = 29
		AND betteam = N'1'

	-- Return data
	BEGIN
		IF @IsCornerParlay = 1
		BEGIN

			SELECT
				rb.custid,
				rb.username,
				SUM(stake * actualrate) AS stakePT,
				SUM(stake * actualrate * (odds2 - 1) * (1 - tpositiontaking)) AS net_win,
				COUNT(1) AS betcount,
				SUM((rb.odds2 - 1) * rb.stake * rb.actualrate)  AS potentialWinningAmt,
				ci.CustomerClass
			FROM rmBettrans rb WITH (NOLOCK)
				INNER JOIN #bettype bt ON rb.bettype = bt.bettype
				INNER JOIN #tmpSelection s ON rb.hdp2 = s.selection
				INNER JOIN #tmpSport sp ON rb.transid2 = sp.sporttype
				INNER JOIN bodb02.dbo.custInfo ci WITH(NOLOCK) ON ci.custID = rb.custid
				LEFT JOIN #Generator o ON rb.transid = o.transid
			CROSS APPLY
			(
				SELECT SUM(t.CornerParlay) as CornerParlay
				FROM
				(
					SELECT	SUM(CASE WHEN m.ChildMatchType = 204 THEN 1 ELSE 0 END) AS CornerParlay
					FROM bodb02.dbo.bettransm bm WITH (NOLOCK)
					LEFT JOIN bodb02.dbo.match m WITH (NOLOCK) ON bm.matchid = m.matchid
					WHERE rb.refno = bm.refno 
					UNION ALL
					SELECT	SUM(CASE WHEN m.ChildMatchType = 204 THEN 1 ELSE 0 END) AS CornerParlay
					FROM bodb02.dbo.bettransm14 bm WITH (NOLOCK)
					LEFT JOIN bodb02.dbo.match14 m WITH (NOLOCK) ON bm.matchid = m.matchid
					WHERE rb.refno = bm.refno 
				)t
			) t
			WHERE rb.recommend = @custid
				AND statusid = 0
				AND (rb.bettype <> 29
					OR (EXISTS(SELECT TOP 1 1 FROM #ParlayType WHERE ParlayType = 1)
						AND rb.bettype = 29 AND rb.betteam = N'1')
					OR (EXISTS(SELECT TOP 1 1 FROM #ParlayType WHERE ParlayType = 2)
						AND rb.bettype = 29 AND rb.betteam <> N'1')
					OR (EXISTS(SELECT TOP 1 1 FROM #ParlayType WHERE ParlayType = 5)
						AND rb.bettype = 29 AND rb.betteam = N'1' AND rb.oddsspread = 1)
					OR (EXISTS(SELECT TOP 1 1 FROM #ParlayType WHERE ParlayType = 6)
						AND rb.bettype = 29 AND rb.betteam = N'1' AND o.bac|16 = o.bac)
					OR (EXISTS(SELECT TOP 1 1 FROM #ParlayType WHERE ParlayType = 7)
						AND rb.bettype = 29 AND rb.betteam = N'1' AND rb.oddsspread = 2)
					OR (EXISTS(SELECT TOP 1 1 FROM #ParlayType WHERE ParlayType = 8)
						AND rb.bettype = 29 AND rb.betteam = N'1' AND rb.oddsspread = 3)
					)		
				AND t.CornerParlay > 0
			GROUP BY rb.custid,	rb.username, ci.CustomerClass
			ORDER  BY net_win DESC

		END
		ELSE
		BEGIN
			SELECT
				rb.custid,
				rb.username,
				SUM(stake * actualrate) AS stakePT,
				SUM(stake * actualrate * (odds2 - 1) * (1 - tpositiontaking)) AS net_win,
				COUNT(1) AS betcount,
				SUM((rb.odds2 - 1) * rb.stake * rb.actualrate)  AS potentialWinningAmt,
				ci.CustomerClass
			FROM rmBettrans rb WITH (NOLOCK)
				INNER JOIN #bettype bt ON rb.bettype = bt.bettype
				INNER JOIN #tmpSelection s ON rb.hdp2 = s.selection
				INNER JOIN #tmpSport sp ON rb.transid2 = sp.sporttype
				INNER JOIN bodb02.dbo.custInfo ci WITH(NOLOCK) ON ci.custID = rb.custid
				LEFT JOIN #Generator o ON rb.transid = o.transid
			WHERE rb.recommend = @custid
				AND statusid = 0
				AND (rb.bettype <> 29
					OR (EXISTS(SELECT TOP 1 1 FROM #ParlayType WHERE ParlayType = 1)
						AND rb.bettype = 29 AND rb.betteam = N'1')
					OR (EXISTS(SELECT TOP 1 1 FROM #ParlayType WHERE ParlayType = 2)
						AND rb.bettype = 29 AND rb.betteam <> N'1')
					OR (EXISTS(SELECT TOP 1 1 FROM #ParlayType WHERE ParlayType = 5)
						AND rb.bettype = 29 AND rb.betteam = N'1' AND rb.oddsspread = 1)
					OR (EXISTS(SELECT TOP 1 1 FROM #ParlayType WHERE ParlayType = 6)
						AND rb.bettype = 29 AND rb.betteam = N'1' AND o.bac|16 = o.bac)
					OR (EXISTS(SELECT TOP 1 1 FROM #ParlayType WHERE ParlayType = 7)
						AND rb.bettype = 29 AND rb.betteam = N'1' AND rb.oddsspread = 2)
					OR (EXISTS(SELECT TOP 1 1 FROM #ParlayType WHERE ParlayType = 8)
						AND rb.bettype = 29 AND rb.betteam = N'1' AND rb.oddsspread = 3)
					)		
			GROUP BY  rb.custid, rb.username, ci.CustomerClass
			ORDER  BY net_win DESC
		END
		
	END

	DROP TABLE #bettype
	DROP TABLE #ParlayType
	DROP TABLE #tmpSelection
	DROP TABLE #tmpSport
	DROP TABLE #Generator
END
GO