/*<info serverAlias="DBRMS-bodb_RMS" executers="bodbRMSNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[RMS_Monitor_ComboParlay_Betlist]
	@selection		VARCHAR(MAX) = '0'
	,@sporttype		VARCHAR(100) = ''
	,@level			VARCHAR(100) = ''
	,@Market		VARCHAR(100) = ''
	,@stake			MONEY = 0
	,@maxpayout		MONEY = 0
	,@ReportType	TINYINT = 1
	,@max_transid	BIGINT = 0
	,@limitRowCount	INT = 2000
	,@ParlayType	VARCHAR(20) = ''
	,@IsCornerParlay BIT = 0
	,@Odds			SMALLMONEY = NULL
	,@CustomerClass	SMALLINT = NULL
	,@leagueGroupId VARCHAR(200)
	,@company		VARCHAR(MAX) = '' 
AS

/*
	Created: 20160425@Winnie
	Task: Monitoring bets combo parlay of special members
	DB: DBRMS-bodb_RMS
	
	Revisions:
		- 20160926@Winnie: fix issue conflict refno with racing RedmineID: #64286
		- 20170719@Winnie: Add MuayThai RedmineID: #79500
		- 20190214@Jacob: Add Bet Builder RedmineID: #108694
		- 20200510@Percy: Add Penalty Shootout Combo [RedmineID: #133961]
		- 20200821@Percy: Fix issue duplicate data due to MBBU process [RedmineID: #140078]
		- 20201124@Percy: Enhance performance to support increase @limitRowcount [RedmineID: #145927]
		- 20201211@Danny: Monitor Corner Parlay Tickets [RedmineID: #146929]
		- 20201204@Danny: Separate Data of Virtual Soccer & Virtual Basketball  [RedmineID: #145926]
		- 20210218@Danny: Monitor Performance of GOF  [RedmineID: #149966]
		- 20210319@Danny: Incorporate Cricket AIO into PRMS [RedmineID: #151319]
		- 20210628@Danny: Add Column Member Potential Winning [RedmineID: #156979]
		- 20210629@Danny: Add filtering by Customer Class[RedmineID: #156980]
		- 20211001@Danny: Change dataType to support IPv6 and enhance performance [RedmineID: #162348]
		- 20211007@Danny: Track User Monitoring [RedmineID: #162872]
		- 20220301@Danny: add filter by Site [RedmineID: #169072]

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
		- @level:
					. '0': none
					. '1,2,3': level 1,2,3
		- @ReportType:
					. 1: Filter by stake
					. 2: filter by net win
		- @Market:
					. 1: Today only maket
					. 2: Early only maket
					. 3: Combined	
		- @ParlayType:
					. 1: Mix parlay
					. 2: Combo parlay
					. 3: Single Match Parlay
					. 4: Panalty shootout combo
					. 5: GOF
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @MBU TABLE (BalanceUpDay SMALLDATETIME, MoveBetsDay SMALLDATETIME)
	INSERT INTO @MBU (BalanceUpDay, MoveBetsDay)
	EXEC bodb02.dbo.Age_SelBalanceUpDay

	DECLARE @BalanceUpDay SMALLDATETIME, @MoveBetsDay SMALLDATETIME
	SELECT  @BalanceUpDay = BalanceUpDay, @MoveBetsDay = MoveBetsDay FROM @MBU

	DECLARE @today SMALLDATETIME
	SELECT  @today = CONVERT(DATE, GETDATE())

	CREATE TABLE #company(Site NVARCHAR(50))

	INSERT INTO #company(Site)
	select val from  dbo.f_RMS_strSplit(@company, ',')


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

	-- Blacklist league
	DECLARE @BlacklistLeagueGroupId INT
	SELECT  @BlacklistLeagueGroupId = GroupId FROM dbo.rmLeagueGroup WITH (NOLOCK) WHERE GroupName = 'Blacklist'
	
	-- League 
	DECLARE @leagueGroupIdTab TABLE (LeagueGroupId INT)
	INSERT INTO @leagueGroupIdTab
	SELECT val FROM dbo.f_RMS_strSplit(@leagueGroupId, ',')

	CREATE TABLE #League (LeagueID INT)
	INSERT INTO #League (LeagueID)
	SELECT LeagueID 
	FROM  dbo.rmLeague  t WITH(NOLOCK)
	INNER JOIN @leagueGroupIdTab tb ON t.GroupId = tb.LeagueGroupId

	IF EXISTS (SELECT 1 FROM @leagueGroupIdTab WHERE LeagueGroupId = -1)
	BEGIN
		INSERT INTO #League (LeagueID)
		SELECT l.LeagueID 
		FROM   bodb02.dbo.League  l WITH(NOLOCK)
		LEFT JOIN dbo.rmLeague  t WITH(NOLOCK) ON l.leagueid = t.LeagueId
		WHERE t.LeagueId IS NULL
	END

	-- get data
	BEGIN
		CREATE TABLE #bettrans
		(
			transid				BIGINT
			,refno				BIGINT
			,matchid			INT
			,bettype			SMALLINT
			,market				TINYINT -- 1: today only, 2: early only, 3: combined
			,NumberWon			INT DEFAULT(0)
			,IsLive				BIT DEFAULT(0)
			,IsBlacklistLeague	BIT DEFAULT(0)
			,IsCornerParlay		BIT DEFAULT(0)
			,isSelected			BIT DEFAULT(0)
		)
		
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

		DECLARE @min_transid BIGINT
		SELECT  @min_transid = MIN(transid) FROM dbo.rmBettrans WITH (NOLOCK) WHERE  winlostdate >= @today AND  statusID = 0

		-- Get main ticket
		IF EXISTS (SELECT 1 FROM #bettype WHERE bettype = 29) 
		BEGIN
			INSERT INTO #bettrans (transid, bettype, matchid, refno)
			SELECT  DISTINCT b.transid, b.bettype, b.matchid, b.refno
			FROM dbo.rmBettrans b WITH (NOLOCK)
				INNER JOIN #tmpSelection s ON b.hdp2 = s.selection
				INNER JOIN #tmpSport sp ON b.transid2 = sp.sporttype
				INNER JOIN bodb02.dbo.Customer ct WITH(NOLOCK) ON b.custid = ct.custid
				INNER JOIN #company cp ON cp.Site = ct.site
			WHERE b.transid >= @min_transid
			AND b.statusID = 0
			AND b.currency <> 20
			AND b.bettype = 29 
		END
	
		IF EXISTS (SELECT 1 FROM #bettype WHERE bettype IN (38, 376)) 
		BEGIN
			INSERT INTO #bettrans (transid, bettype, matchid, refno, isSelected)
			SELECT  b.transid, b.bettype, b.matchid, b.refno, 1
			FROM dbo.rmBettrans b WITH (NOLOCK)
				INNER JOIN #bettype bt ON b.bettype = bt.bettype
				INNER JOIN #tmpSelection s ON b.hdp2 = s.selection
				INNER JOIN #tmpSport sp ON b.transid2 = sp.sporttype
				INNER JOIN bodb02.dbo.match m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN bodb02.dbo.Customer ct WITH(NOLOCK) ON b.custid = ct.custid
				INNER JOIN #company cp ON cp.Site = ct.site

			WHERE b.transid >= @min_transid
			AND b.statusID = 0
			AND b.currency <> 20
			AND m.leagueid IN  (SELECT x.LeagueId FROM #League x)
		END

		DROP TABLE #bettype
		DROP TABLE #tmpSelection
		DROP TABLE #tmpSport
		DROP TABLE #company

		CREATE CLUSTERED INDEX cix_#bettrans ON #bettrans(bettype, refno)

		IF EXISTS (SELECT 1 FROM #bettrans WHERE bettype IN (38, 376))
		BEGIN
	
			UPDATE b
			SET b.market = CASE
								WHEN m.eventdate = @today THEN 1 -- today only
								ELSE 2 END -- early only
				,b.IsLive = CASE
								WHEN m.GlobalShowTime < GETDATE() AND m.eventstatus <> 'Completed' THEN 1
								ELSE 0 END
				,b.IsBlacklistLeague = CASE WHEN l.LeagueId IS NOT NULL THEN 1 ELSE 0 END
			FROM #bettrans b
				INNER JOIN bodb02.dbo.match m WITH (NOLOCK) ON b.matchid = m.matchid
				LEFT JOIN dbo.rmLeague l WITH (NOLOCK) ON m.leagueid = l.LeagueId AND l.GroupId = @BlacklistLeagueGroupId
			WHERE b.bettype IN (38, 376)
		END

		DECLARE @minRefno BIGINT,
				@maxRefno BIGINT

		CREATE TABLE #bettransmInfo (
			refno			BIGINT, 
			LeagueId		INT, 
			StatusID		SMALLINT, 
			matchdate		SMALLDATETIME, 
			GlobalShowTime  SMALLDATETIME,
			eventstatus		NVARCHAR(50),
			ChildMatchType	TINYINT,
			isSelected		INT,
			IsBlacklistLeague INT
		)

		IF EXISTS (SELECT 1 FROM #bettrans WHERE bettype = 29)
		BEGIN

			SELECT	@minRefno = MIN(refno), @maxRefno = MAX(refno)
			FROM	#bettrans
			WHERE	bettype = 29

			INSERT INTO #bettransmInfo (refno, LeagueId, StatusID, matchdate, GlobalShowTime, eventstatus, ChildMatchType, isSelected, IsBlacklistLeague)
			SELECT bm.refno, m.leagueid, bm.statusID, bm.matchdate, m.GlobalShowTime, m.eventstatus, m.ChildMatchType, CASE WHEN lg.LeagueID IS NULL THEN 0 ELSE 1 END isSelected, CASE WHEN l.LeagueId IS NULL THEN 0 ELSE 1 END IsBlacklistLeague
			FROM bodb02.dbo.bettransm bm WITH (NOLOCK)
				INNER JOIN #bettrans bt ON bt.refno = bm.refno
				INNER JOIN bodb02.dbo.match m WITH (NOLOCK) ON bm.matchid = m.matchid
				LEFT JOIN #League lg ON lg.LeagueID = m.leagueid
				LEFT JOIN dbo.rmLeague l WITH (NOLOCK) ON m.leagueid = l.LeagueId AND l.GroupId = @BlacklistLeagueGroupId
			WHERE bm.refno BETWEEN @minRefno AND @maxRefno  AND (bm.statusID IN (0, 1) OR bm.winlostdate > @MoveBetsDay)

			UNION ALL

			SELECT bm.refno, m.leagueid, bm.statusID, bm.matchdate, m.GlobalShowTime, m.eventstatus, m.ChildMatchType, CASE WHEN lg.LeagueID IS NULL THEN 0 ELSE 1 END isSelected, CASE WHEN l.LeagueId IS NULL THEN 0 ELSE 1 END IsBlacklistLeague
			FROM bodb02.dbo.bettransm14 bm WITH (NOLOCK)
				INNER JOIN #bettrans bt ON bt.refno = bm.refno
				INNER JOIN bodb02.dbo.match m WITH (NOLOCK) ON bm.matchid = m.matchid
				LEFT JOIN #League lg ON lg.LeagueID = m.leagueid
				LEFT JOIN dbo.rmLeague l WITH (NOLOCK) ON m.leagueid = l.LeagueId AND l.GroupId = @BlacklistLeagueGroupId
			WHERE  bm.refno BETWEEN @minRefno AND @maxRefno AND bm.winlostdate BETWEEN @BalanceUpDay AND @MoveBetsDay

			UNION ALL

			SELECT bm.refno, m.leagueid, bm.statusID, bm.matchdate, m.GlobalShowTime, m.eventstatus, m.ChildMatchType, CASE WHEN lg.LeagueID IS NULL THEN 0 ELSE 1 END isSelected, CASE WHEN l.LeagueId IS NULL THEN 0 ELSE 1 END IsBlacklistLeague
			FROM dbo.rmBettransm_bk bm WITH (NOLOCK)
				INNER JOIN #bettrans bt ON bt.refno = bm.refno
				INNER JOIN  dbo.rmMatch_bk m WITH (NOLOCK) ON bm.matchid = m.matchid
				LEFT JOIN #League lg ON lg.LeagueID = m.leagueid
				LEFT JOIN dbo.rmLeague l WITH (NOLOCK) ON m.leagueid = l.LeagueId AND l.GroupId = @BlacklistLeagueGroupId
			WHERE  bm.refno BETWEEN @minRefno AND @maxRefno AND bm.winlostdate < @BalanceUpDay 

			CREATE CLUSTERED INDEX cix_#bettransmInfo ON #bettransmInfo (refno)

			UPDATE b
			SET b.NumberWon = bm.NumberWon
				,b.market = CASE
								WHEN today = 1 AND early = 0 THEN 1 -- today only
								WHEN today = 0 AND early = 1 THEN 2 -- early only
								ELSE 3 END -- combined
				,b.IsLive = bm.IsLive
				,b.IsBlacklistLeague = CASE WHEN bm.IsBlacklistLeague > 0 THEN 1 ELSE 0 END
				,b.IsCornerParlay	 =  bm.IsCornerParlay
				,b.isSelected		 = CASE WHEN  bm.isSelected > 0 THEN 1 ELSE 0 END
			FROM #bettrans b
			CROSS APPLY(
							SELECT		SUM(CASE WHEN bm.StatusID = 112 THEN 1 ELSE 0 END) AS NumberWon,
										MAX(CASE WHEN bm.matchdate = @today THEN 1 ELSE 0 END) AS today,
										MAX(CASE WHEN bm.matchdate = @today THEN 0 ELSE 1 END) AS early,
										MIN(CASE WHEN bm.GlobalShowTime < GETDATE() AND bm.eventstatus <> 'Completed' THEN 1 ELSE 0 END) AS IsLive,
										SUM(IsBlacklistLeague) AS IsBlacklistLeague,
										MAX(CASE WHEN bm.ChildMatchType = 204 THEN 1 ELSE 0 END) AS IsCornerParlay,
										SUM(bm.isSelected) AS isSelected
							FROM 		#bettransmInfo bm
							WHERE		bm.refno = b.refno
					) bm
			WHERE b.bettype = 29 
		END
	END

	-- Return data
	BEGIN
		CREATE TABLE #level (level TINYINT)
		INSERT INTO #level (level)
		SELECT DISTINCT val FROM dbo.f_RMS_strSplit(@level, ',')

		CREATE TABLE #Result
		(
			custid INT
			,transdate DATETIME
			,transid BIGINT
			,refno BIGINT
			,username VARCHAR(30)
			,sporttype INT
			,odds MONEY
			,statusId TINYINT
			,stake MONEY
			,maxpayout MONEY
			,TotalSelection INT
			,TotalBet INT
			,IP VARCHAR(45)
			,level TINYINT
			,NumberWon INT
			,bettype INT
			,IsLive BIT
			,IsBlacklistLeague BIT
			,betteam NVARCHAR(10)
			,oddsspread SMALLMONEY
			,IsGOF BIT
			,potentialWinningAmt MONEY
			,CustomerClass SMALLINT
			,TrackingUser NVARCHAR(50)
		)
		INSERT INTO #Result
		(
			custid, transdate, transid, refno, username, sporttype, odds, statusId, stake, maxpayout
			,TotalSelection, TotalBet, IP, level, NumberWon, bettype, IsLive, IsBlacklistLeague, betteam, oddsspread, IsGOF, potentialWinningAmt, CustomerClass , TrackingUser
		)
		SELECT
			rb.custid
			,rb.transdate
			,rb.transid
			,rb.refno
			,rb.username
			,CASE WHEN transid2 NOT IN (-1,-3,1,2,3,4,5,6,7,8,9,11,43,44,-4,-5) THEN -2 ELSE transid2 END AS Sporttype
			,rb.odds2 * rb.TotalBet AS odds
			,rb.statusID
			,rb.stake * rb.actualrate * (1 - rb.tpositiontaking) / rb.TotalBet AS stake
			,(rb.odds2 - 1) * rb.stake * rb.actualrate * (1 - rb.tpositiontaking) AS maxpayout
			,rb.hdp2 AS TotalSelection
			,rb.TotalBet AS TotalBet
			,rb.IP
			,ISNULL(mc.level, 0) AS level
			,b.NumberWon
			,rb.bettype
			,b.IsLive
			,b.IsBlacklistLeague
			,rb.betteam
			,rb.oddsspread
			,CASE WHEN rb.bettype = 29 AND rb.betteam = N'1' AND rb.oddsspread = 1 THEN 1 ELSE 0 END
			,(rb.odds2 - 1) * rb.stake * rb.actualrate
			,ci.CustomerClass
			,l.username AS TrackingUser
		FROM rmBettrans rb WITH (NOLOCK)
			INNER JOIN #bettrans b ON rb.transid = b.transid AND b.isSelected = 1
			INNER JOIN bodb02.dbo.CustInfo ci WITH(NOLOCK) ON rb.custid = ci.custid
			LEFT JOIN rmCustomer mc WITH (NOLOCK) ON rb.custid = mc.custid
			LEFT JOIN dbo.rmUserTrackingLog l WITH(NOLOCK) ON rb.transid = l.transid
		WHERE ISNULL(mc.level, 0) IN (SELECT level FROM #level)
		AND ((rb.odds2 * rb.TotalBet) <= @Odds OR @Odds IS NULL)
			AND (ci.CustomerClass = @CustomerClass OR @CustomerClass IS NULL)
			AND  (rb.stake * rb.actualrate * (1 - rb.tpositiontaking) / rb.TotalBet) >= CASE WHEN @reportType = 1 THEN @stake ELSE 0 END
			AND  ((rb.odds2 - 1) * rb.stake * rb.actualrate * (1 - rb.tpositiontaking)) >= CASE WHEN @reportType = 2 THEN @maxpayout ELSE 0 END
			AND  b.market IN (SELECT DISTINCT val FROM dbo.f_RMS_strSplit(@Market, ','))
			AND b.IsCornerParlay = CASE WHEN @IsCornerParlay = 1 THEN 1 ELSE b.IsCornerParlay END

		IF @ComboType IN (1,2,3,4,5,6)
		BEGIN
			CREATE CLUSTERED INDEX CIX_#Result ON #Result (bettype, betteam, oddsspread)

			IF @ComboType = 1 -- Mix parlay only
				DELETE #Result WHERE bettype = 29 AND  betteam <> N'1' OR (bettype = 29 AND betteam = N'1' AND oddsspread = 1)
				ELSE IF @ComboType = 2 -- Combo parlay only
					DELETE #Result WHERE bettype = 29 AND betteam = N'1'
					ELSE IF @ComboType = 3 -- GOF only
						DELETE #Result WHERE (bettype = 29 AND betteam <> N'1') OR (bettype = 29 AND betteam = N'1' AND (oddsspread <> 1 OR oddsspread IS NULL))
						ELSE IF @ComboType = 4  -- combined between mix parlay and GOF
							DELETE #Result WHERE bettype = 29 AND betteam <> N'1'
							ELSE IF @ComboType = 5  -- combined between combo parlay and GOF
								DELETE #Result WHERE bettype = 29 AND  betteam = N'1' AND (oddsspread <> 1 OR oddsspread IS NULL)
								ELSE IF @ComboType = 6  -- combined between mix parlay and combo parlay
									DELETE #Result WHERE bettype = 29 AND  betteam = N'1' AND oddsspread = 1
		END

		CREATE INDEX IX_Index ON #Result (transid)
		
		SELECT custid, transdate, transid, refno, username, sporttype, odds, statusId, stake, maxpayout
			,TotalSelection, TotalBet, IP, level, 0 AS IsBetRadar, NumberWon, bettype, IsLive, IsBlacklistLeague, IsGOF, potentialWinningAmt, CustomerClass, TrackingUser
		FROM (
				SELECT custid, transdate, transid, refno, username, sporttype, odds, statusId, stake, maxpayout
					,TotalSelection, TotalBet, IP, level, NumberWon, bettype, IsLive, IsBlacklistLeague, IsGOF, potentialWinningAmt, CustomerClass, TrackingUser
					,ROW_NUMBER() OVER(ORDER BY transid DESC) AS rn
				FROM #Result
			) r
		WHERE rn <= @limitRowCount
	END
	
	DROP TABLE #bettransmInfo
	DROP TABLE #bettrans
	DROP TABLE #level
	DROP TABLE #Result
	DROP TABLE #League

END
GO