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
	,@UserName		NVARCHAR(50) = ''
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
		- 20220519@Danny: add filter by username [RedmineID: #172691]
		- 20221121@Danny: enhance perfomance [RedmineID: #180707]
		- 20230320@Cherry: Change formula of Stake (#185251)
		- 20230420@Cherry: Add Site column (#186735)
		- 20230824@Cherry: Parlay Boost Bonus (#192681)
		- 20231020@Cherry: Parlay Generator (#195498)

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
					. 6: Parlay Generator
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

	CREATE TABLE #userList(custID INT) -- member	
	DECLARE @custID INT, @RoleID TINYINT

	IF @UserName <> ''
	BEGIN
		SELECT @custID = custid, @RoleID = roleid
		FROM	bodb02.dbo.custInfo WITH(NOLOCK)
		WHERE  username = @UserName
	
		IF @RoleID = 4 
			BEGIN
			INSERT INTO #userList (custID)
			SELECT	custid
			FROM	bodb02.dbo.custInfo WITH(NOLOCK)
			WHERE  srecommend = @custID AND roleid = 1
		END

		IF @RoleID = 3 
			BEGIN
			INSERT INTO #userList (custID)
			SELECT	custid
			FROM	bodb02.dbo.custInfo WITH(NOLOCK)
			WHERE  mrecommend = @custID AND roleid = 1
		END

		IF @RoleID = 2 
			BEGIN
			INSERT INTO #userList (custID)
			SELECT	custid
			FROM	bodb02.dbo.custInfo WITH(NOLOCK)
			WHERE  recommend = @custID AND roleid = 1
		END

		IF @RoleID = 1 
			BEGIN
			INSERT INTO #userList (custID)
			SELECT	custid
			FROM	bodb02.dbo.custInfo WITH(NOLOCK)
			WHERE  custid = @custID AND roleid = 1
		END
	END

	CREATE TABLE #company(Site NVARCHAR(50))
	INSERT INTO #company(Site)
	select value from  STRING_SPLIT(@company, ',')

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

	-- Blacklist league
	DECLARE @BlacklistLeagueGroupId INT
	SELECT  @BlacklistLeagueGroupId = GroupId FROM dbo.rmLeagueGroup WITH (NOLOCK) WHERE GroupName = 'Blacklist'
	
	-- League 
	DECLARE @leagueGroupIdTab TABLE (LeagueGroupId INT)
	INSERT INTO @leagueGroupIdTab
	SELECT value FROM STRING_SPLIT(@leagueGroupId, ',')

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

		CREATE TABLE #tmpBettrans (transid BIGINT, bact INT)
		
		CREATE TABLE #bettype (bettype SMALLINT)

		CREATE TABLE #ParlayType (ParlayType SMALLINT)
	
		IF ',' + @ParlayType + ',' LIKE '%,1,%' OR ',' + @ParlayType + ',' LIKE '%,2,%' OR ',' + @ParlayType + ',' LIKE '%,5,%' OR ',' + @ParlayType + ',' LIKE '%,6,%'
		BEGIN
			INSERT INTO #bettype (bettype)
			VALUES (29)

			INSERT INTO #ParlayType (ParlayType)
			SELECT	value
			FROM STRING_SPLIT(@ParlayType, ',') 
			WHERE value IN (1,2,5,6)
		END

		-- Single match parlay
		IF ',' + @ParlayType + ',' LIKE '%,3,%'
			INSERT INTO #bettype (bettype)
			VALUES (38)

		-- Penalty shootout combo
		IF ',' + @ParlayType + ',' LIKE '%,4,%'
			INSERT INTO #bettype (bettype)
			VALUES (376)

		-- Get main ticket
		IF EXISTS (SELECT 1 FROM #bettype WHERE bettype = 29) 
		BEGIN
			INSERT INTO #tmpBettrans(transid, bact)
			SELECT transid,
				ISNULL(TRY_CAST(TRY_CAST(ExtraInfo AS XML).value('(/p1/@bact)[1]', 'VARCHAR(50)') AS INT),0)
			FROM 
				dbo.rmBettrans WITH (NOLOCK)
			WHERE winlostdate >= @today
				AND statusID = 0
				AND currency <> 20
				AND bettype = 29 
				AND matchid = 29
				AND betteam = N'1'

			INSERT INTO #bettrans (transid, bettype, matchid, refno)
			SELECT  DISTINCT b.transid, b.bettype, b.matchid, b.refno
			FROM dbo.rmBettrans b WITH (NOLOCK)
				INNER JOIN #tmpSelection s ON b.hdp2 = s.selection
				INNER JOIN #tmpSport sp ON b.transid2 = sp.sporttype
				INNER JOIN bodb02.dbo.Customer ct WITH(NOLOCK) ON b.custid = ct.custid
				INNER JOIN #company cp ON cp.Site = ct.site
				LEFT JOIN #tmpBettrans t ON b.transid = t.transid
			WHERE b.winlostdate >= @today
			AND (b.custid IN (SELECT ul.custID FROM #userList ul) OR @UserName = '')
			AND b.matchid = 29
			AND b.statusID = 0
			AND b.currency <> 20
			AND b.bettype = 29 
			AND (
				(EXISTS(SELECT TOP 1 1 FROM #ParlayType WHERE ParlayType = 1)
					AND b.bettype = 29 AND b.betteam = N'1')
				OR (EXISTS(SELECT TOP 1 1 FROM #ParlayType WHERE ParlayType = 2)
					AND b.bettype = 29 AND b.betteam <> N'1')
				OR (EXISTS(SELECT TOP 1 1 FROM #ParlayType WHERE ParlayType = 5)
					AND b.bettype = 29 AND b.betteam = N'1' AND b.oddsspread = 1)
				OR (EXISTS(SELECT TOP 1 1 FROM #ParlayType WHERE ParlayType = 6)
					AND t.bact = 5)
				)		
			
		END
	
		IF EXISTS (SELECT 1 FROM #bettype WHERE bettype IN (38, 376)) 
		BEGIN
			INSERT INTO #bettrans (transid, bettype, matchid, refno, isSelected, market, IsLive, IsBlacklistLeague)
			SELECT  b.transid, b.bettype, b.matchid, b.refno, 1, 
					CASE WHEN m.eventdate = @today THEN 1 -- today only
					ELSE 2 END market, -- early only
					CASE WHEN m.GlobalShowTime < GETDATE() AND m.eventstatus <> 'Completed' THEN 1
					ELSE 0 END  IsLive,
					 CASE WHEN l.LeagueId IS NOT NULL THEN 1 ELSE 0 END IsBlacklistLeague
			FROM dbo.rmBettrans b WITH (NOLOCK)
				INNER JOIN #bettype bt ON b.bettype = bt.bettype
				INNER JOIN #tmpSelection s ON b.hdp2 = s.selection
				INNER JOIN #tmpSport sp ON b.transid2 = sp.sporttype
				INNER JOIN bodb02.dbo.match m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN bodb02.dbo.Customer ct WITH(NOLOCK) ON b.custid = ct.custid
				INNER JOIN #company cp ON cp.Site = ct.site
				LEFT JOIN dbo.rmLeague l WITH (NOLOCK) ON m.leagueid = l.LeagueId AND l.GroupId = @BlacklistLeagueGroupId

			WHERE b.winlostdate >= @today
			AND (b.custid IN (SELECT ul.custID FROM #userList ul) OR @UserName = '')
			AND b.statusID = 0
			AND b.currency <> 20
			AND b.bettype IN (38, 376)
			AND m.leagueid IN  (SELECT x.LeagueId FROM #League x)
			
		END

		DROP TABLE #bettype
		DROP TABLE #tmpSelection
		DROP TABLE #tmpSport
		DROP TABLE #company

		CREATE CLUSTERED INDEX cix_#bettrans ON #bettrans(bettype, refno)

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

			INSERT INTO #bettransmInfo (refno, LeagueId, StatusID, matchdate, GlobalShowTime, eventstatus, ChildMatchType, isSelected, IsBlacklistLeague)
			SELECT bm.refno, bm.leagueid, bm.statusID, bm.matchdate, bm.GlobalShowTime, bm.eventstatus, bm.ChildMatchType,  CASE WHEN lg.LeagueID IS NULL THEN 0 ELSE 1 END isSelected, CASE WHEN l.LeagueId IS NULL THEN 0 ELSE 1 END IsBlacklistLeague
			FROM    #bettrans bt
			CROSS APPLY(
				SELECT bm.refno, m.leagueid, bm.statusID, bm.matchdate, m.GlobalShowTime, m.eventstatus, m.ChildMatchType
				FROM bodb02.dbo.bettransm bm WITH (NOLOCK)
				INNER JOIN bodb02.dbo.match m WITH (NOLOCK) ON bm.matchid = m.matchid
				WHERE  bm.refno = bt.refno AND  (bm.statusID IN (0, 1) OR bm.winlostdate > @MoveBetsDay)

				UNION ALL

				SELECT bm.refno, m.leagueid, bm.statusID, bm.matchdate, m.GlobalShowTime, m.eventstatus, m.ChildMatchType
				FROM bodb02.dbo.bettransm14 bm WITH (NOLOCK)
					INNER JOIN bodb02.dbo.match14 m WITH (NOLOCK) ON bm.matchid = m.matchid
				WHERE  bm.refno = bt.refno AND  bm.winlostdate BETWEEN @BalanceUpDay AND @MoveBetsDay

				UNION ALL
				SELECT bm.refno, m.leagueid, bm.statusID, bm.matchdate, m.GlobalShowTime, m.eventstatus, m.ChildMatchType
				FROM dbo.rmBettransm_bk bm WITH (NOLOCK)
					INNER JOIN  dbo.rmMatch_bk m WITH (NOLOCK) ON bm.matchid = m.matchid
				WHERE bm.refno = bt.refno AND   bm.winlostdate >= DATEADD(DAY, -21, @BalanceUpDay)  and  bm.winlostdate < @BalanceUpDay 

			) bm
			LEFT JOIN #League lg ON lg.LeagueID = bm.leagueid
			LEFT JOIN dbo.rmLeague l WITH (NOLOCK) ON bm.leagueid = l.LeagueId AND l.GroupId = @BlacklistLeagueGroupId

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
		SELECT DISTINCT value FROM STRING_SPLIT(@level, ',')

		CREATE TABLE #Result
		(
			custid INT
			,transdate DATETIME
			,IsBoostBonus BIT
			,transid BIGINT
			,refno BIGINT
			,SiteGroup VARCHAR(10)
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
			,IsParlayGenerator BIT
			,potentialWinningAmt MONEY
			,CustomerClass SMALLINT
			,TrackingUser NVARCHAR(50)
		)
		INSERT INTO #Result
		(
			custid, transdate, IsBoostBonus, transid, refno, SiteGroup, username, sporttype, odds, statusId, stake, maxpayout
			,TotalSelection, TotalBet, IP, level, NumberWon, bettype, IsLive, IsBlacklistLeague, betteam, oddsspread, IsGOF, IsParlayGenerator, potentialWinningAmt, CustomerClass , TrackingUser
		)
		SELECT
			rb.custid
			,rb.transdate
			,CASE WHEN rb.bettype = 29 AND rb.betteam = N'1' AND rb.oddsspread = 2 THEN 1 ELSE 0 END IsBoostBonus
			,rb.transid
			,rb.refno
			,CASE WHEN s.isDeposit = 0 OR s.site = 'Saba789' THEN 'C' ELSE 'L' END
			,rb.username
			,CASE WHEN transid2 NOT IN (-1,-3,1,2,3,4,5,6,7,8,9,11,43,44,-4,-5) THEN -2 ELSE transid2 END AS Sporttype
			,rb.odds2 * rb.TotalBet AS odds
			,rb.statusID
			,rb.stake * rb.actualrate AS stake
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
			,CASE WHEN t.bact = 5 THEN 1 ELSE 0 END
			,(rb.odds2 - 1) * rb.stake * rb.actualrate
			,ci.CustomerClass
			,l.username AS TrackingUser
		FROM rmBettrans rb WITH (NOLOCK)
			INNER JOIN #bettrans b ON rb.transid = b.transid AND b.isSelected = 1
			INNER JOIN bodb02.dbo.CustInfo ci WITH(NOLOCK) ON rb.custid = ci.custid
			LEFT JOIN #tmpBettrans t ON rb.transid = t.transid
			LEFT JOIN rmCustomer mc WITH (NOLOCK) ON rb.custid = mc.custid
			LEFT JOIN dbo.rmUserTrackingLog l WITH(NOLOCK) ON rb.transid = l.transid
			LEFT JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON c.custid = rb.custid
			LEFT JOIN bodb02.dbo.Site s WITH(NOLOCK) ON c.site = s.site
		WHERE ISNULL(mc.level, 0) IN (SELECT level FROM #level)
			AND ((rb.odds2 * rb.TotalBet) <= @Odds OR @Odds IS NULL)
			AND (ci.CustomerClass = @CustomerClass OR @CustomerClass IS NULL)
			AND  (rb.stake * rb.actualrate) >= CASE WHEN @reportType = 1 THEN @stake ELSE 0 END
			AND  ((rb.odds2 - 1) * rb.stake * rb.actualrate * (1 - rb.tpositiontaking)) >= CASE WHEN @reportType = 2 THEN @maxpayout ELSE 0 END
			AND  b.market IN (SELECT DISTINCT value FROM STRING_SPLIT(@Market, ','))
			AND b.IsCornerParlay = CASE WHEN @IsCornerParlay = 1 THEN 1 ELSE b.IsCornerParlay END		

		CREATE INDEX IX_Index ON #Result (transid)
		
		SELECT custid, transdate, IsBoostBonus, transid, refno, SiteGroup, username, sporttype, odds, statusId, stake, maxpayout
			,TotalSelection, TotalBet, IP, level, 0 AS IsBetRadar, NumberWon, bettype, IsLive, IsBlacklistLeague, IsGOF, IsParlayGenerator, potentialWinningAmt, CustomerClass, TrackingUser
		FROM (
				SELECT custid, transdate, IsBoostBonus, transid, refno, SiteGroup, username, sporttype, odds, statusId, stake, maxpayout
					,TotalSelection, TotalBet, IP, level, NumberWon, bettype, IsLive, IsBlacklistLeague, IsGOF, IsParlayGenerator, potentialWinningAmt, CustomerClass, TrackingUser
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
	DROP TABLE #ParlayType
	DROP TABLE #userList
	DROP TABLE #tmpBettrans

END
GO