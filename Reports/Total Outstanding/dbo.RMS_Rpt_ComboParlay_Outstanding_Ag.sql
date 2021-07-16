/*<info serverAlias="DBRMS-bodb_RMS" executers="bodbRMSNet" isFunction="0" isNested="0"></info>*/
 ALTER PROCEDURE [dbo].[RMS_Rpt_ComboParlay_Outstanding_Ag]
	@custid		INT,	
	@selection	VARCHAR(MAX) = '',
	@sporttype	VARCHAR(100) = '',
	@ParlayType	VARCHAR(10)='',
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
		DECLARE @ComboType TINYINT = 0	
				--1: mix parlay only, 
				--2: combo parlay only, 
				--3: GOF only, 
				--4: combined between mix parlay and GOF, 
				--5: combined between combo parlay and GOF,
				--6: combined between mix parlay and combo parlay, 
				--7: combined all
		
		IF ',' + @ParlayType + ',' LIKE '%,1,%' OR ',' + @ParlayType + ',' LIKE '%,2,%' OR ',' + @ParlayType + ',' LIKE '%,5,%'
		BEGIN
			INSERT INTO #bettype (bettype)
			VALUES (29)

			SELECT	@ComboType = CASE	WHEN COUNT(DISTINCT val) = 3 AND SUM(DISTINCT CAST(val as SMALLINT)) = 8 THEN 7 
										WHEN COUNT(DISTINCT val) = 2 AND SUM(DISTINCT CAST(val as SMALLINT)) = 3 THEN 6
										WHEN COUNT(DISTINCT val) = 2 AND SUM(DISTINCT CAST(val as SMALLINT)) = 6 THEN 4
										WHEN COUNT(DISTINCT val) = 2 AND SUM(DISTINCT CAST(val as SMALLINT)) = 7 THEN 5
										WHEN COUNT(DISTINCT val) = 1 AND SUM(DISTINCT CAST(val as SMALLINT)) = 1 THEN 1
										WHEN COUNT(DISTINCT val) = 1 AND SUM(DISTINCT CAST(val as SMALLINT)) = 2 THEN 2
										WHEN COUNT(DISTINCT val) = 1 AND SUM(DISTINCT CAST(val as SMALLINT)) = 5 THEN 3
								END
			FROM dbo.f_RMS_strSplit(@ParlayType, ',') WHERE val IN (1,2,5)
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

	-- Return data
	BEGIN
		IF @IsCornerParlay = 1
		BEGIN

			SELECT
				rb.custid,
				rb.username,
				SUM(stake * actualrate * (1 - tpositiontaking)) AS stakePT,
				SUM(stake * actualrate * (odds2 - 1) * (1 - tpositiontaking)) AS net_win,
				COUNT(1) AS betcount,
				(rb.odds2 - 1) * rb.stake * rb.actualrate  AS potentialWinningAmt,
				ci.CustomerClass
			FROM rmBettrans rb WITH (NOLOCK)
				INNER JOIN #tmpSelection s ON rb.hdp2 = s.selection
				INNER JOIN #tmpSport sp ON rb.transid2 = sp.sporttype
				INNER JOIN bodb02.dbo.custInfo ci WITH(NOLOCK) ON ci.custID = rb.custid
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
				AND 1 = CASE
						WHEN rb.bettype = 29 AND @ComboType IN (1, 2, 3, 4, 5, 6) THEN CASE
									WHEN @ComboType = 1 AND rb.betteam = N'1' AND rb.oddsspread <> 1 THEN 1
									WHEN @ComboType = 2 AND rb.betteam <> N'1' THEN 1
									WHEN @ComboType = 3 AND rb.betteam = N'1' AND rb.oddsspread = 1 THEN 1
									WHEN @ComboType = 4 AND rb.betteam = N'1' THEN 1
									WHEN @ComboType = 5 AND (rb.betteam <> N'1' OR (rb.betteam = N'1' AND rb.oddsspread = 1)) THEN 1
									WHEN @ComboType = 6 AND (rb.betteam <> N'1' OR (rb.betteam = N'1' AND rb.oddsspread <> 1)) THEN 1
									ELSE 0 END
							ELSE 1 END
				AND t.CornerParlay > 0
			GROUP BY rb.custid,	rb.username, ci.CustomerClass
			ORDER  BY net_win DESC

		END
		ELSE
		BEGIN
			SELECT
				rb.custid,
				rb.username,
				SUM(stake * actualrate * (1 - tpositiontaking)) AS stakePT,
				SUM(stake * actualrate * (odds2 - 1) * (1 - tpositiontaking)) AS net_win,
				COUNT(1) AS betcount,
				(rb.odds2 - 1) * rb.stake * rb.actualrate  AS potentialWinningAmt,
				ci.CustomerClass
		FROM rmBettrans rb WITH (NOLOCK)
				INNER JOIN #tmpSelection s ON rb.hdp2 = s.selection
				INNER JOIN #tmpSport sp ON rb.transid2 = sp.sporttype
				INNER JOIN bodb02.dbo.custInfo ci WITH(NOLOCK) ON ci.custID = rb.custid
			WHERE recommend = @custid
				AND statusid = 0
				AND 1 = CASE
							WHEN rb.bettype = 29 AND @ComboType IN (1, 2, 3, 4, 5, 6) THEN CASE
									WHEN @ComboType = 1 AND rb.betteam = N'1' AND rb.oddsspread <> 1 THEN 1
									WHEN @ComboType = 2 AND rb.betteam <> N'1' THEN 1
									WHEN @ComboType = 3 AND rb.betteam = N'1' AND rb.oddsspread = 1 THEN 1
									WHEN @ComboType = 4 AND rb.betteam = N'1' THEN 1
									WHEN @ComboType = 5 AND (rb.betteam <> N'1' OR (rb.betteam = N'1' AND rb.oddsspread = 1)) THEN 1
									WHEN @ComboType = 6 AND (rb.betteam <> N'1' OR (rb.betteam = N'1' AND rb.oddsspread <> 1)) THEN 1
									ELSE 0 END
							ELSE 1 END
			GROUP BY  rb.custid, rb.username, ci.CustomerClass
			ORDER  BY net_win DESC
		END

		
	END
END
GO