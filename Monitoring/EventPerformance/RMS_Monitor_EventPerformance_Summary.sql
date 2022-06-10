/*<info serverAlias="DBRMS-bodb_RMS" executers="bodbRMSNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[RMS_Monitor_EventPerformance_Summary]
	@selection		VARCHAR(MAX) = '',
	@leagueIDs		VARCHAR(MAX) = '',
	@ParlayType		VARCHAR(10)  = '',
	@level			VARCHAR(100) = '',
	@limitRowCount	INT = 100,
	@CustomerClass	SMALLINT = NULL,
	@isViewDetail	BIT = 0,
	@SportType 		TINYINT = 43,
	@BetTypes		VARCHAR(MAX) = '',
	@UserName		NVARCHAR(50) = ''
AS

/*
	Created: 20211221@Danny
	DB: DBRMS-bodb_RMS
	Task:  Monitor Performance for Event/Bettype/BetChoice (E-sports)

	Revisions:
		- 20211221@Danny: Init SP #165096
		- 20220311@Danny: Support Odd/Even for League Event Monitor [RedmineID: #169796]
		- 20220321@Danny: Add filter by bettype [RedmineID: #169072]
		- 20220408@Danny: Enhance filter by bettype [RedmineID: #171303]
		- 20220425@Danny: Monitor detail Performance for Event/Bettype/BetChoice [RedmineID: #170032]
	
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
					. 5: GOF

		EXEC RMS_Monitor_EventPerformance_Summary 
				@selection		 = '0',
				@leagueIDs		 = '80813',
				@ParlayType		 = '1,2,3,4,5',
				@level			  = '0,1,2,3,4,5,6',
				@limitRowCount	 = 100,
				@CustomerClass	 = NULL

*/

BEGIN
	SET NOCOUNT ON
	DECLARE @yesterday DATE = DATEADD(DAY,-1, GETDATE())

	CREATE TABLE #tmpMainTicket(refno BIGINT, stake MONEY, bettype INT, betteam NVARCHAR(10), oddsspread MONEY)
	CREATE CLUSTERED INDEX cix_#tmpMainTicket ON #tmpMainTicket(refno)

	CREATE TABLE #match(matchID INT, homeID INT, awayID INT, leagueID INT)

	CREATE TABLE #bettransm (refno BIGINT, bettype INT, betteam NVARCHAR(10), matchID INT, odds SMALLMONEY)
	CREATE CLUSTERED INDEX cix_#bettransm ON #bettransm(refno)

	CREATE TABLE #bettype (bettype SMALLINT)
	CREATE TABLE #Result(leagueID INT, HomeTotalStake MONEY, AwayTotalStake MONEY, HomeTotalTicket INT, AwayTotalTicket INT, OtherTotalStake MONEY, OtherTotalTicket INT)
	CREATE TABLE #Details(teamID INT, matchID INT, bettype INT, odds SMALLMONEY, Stake MONEY, Ticket INT, betteam NVARCHAR(10))
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

	-- LeagueIDs
	BEGIN
		CREATE TABLE #tmpLeague (LeagueID INT)
		INSERT INTO #tmpLeague (LeagueID)
		SELECT val FROM dbo.f_RMS_strSplit(@leagueIDs, ',')
	END

	-- #level
	CREATE TABLE #level (level TINYINT)
	INSERT INTO #level (level)
	SELECT DISTINCT val FROM dbo.f_RMS_strSplit(@level, ',')

	-- bettype selection
	CREATE TABLE #bettype_selection (bettype SMALLINT)
	INSERT INTO #bettype_selection(bettype)
	SELECT DISTINCT val FROM dbo.f_RMS_strSplit(@BetTypes, ',')

	-- Userlist
	DECLARE @custID INT, @RoleID TINYINT
	SELECT @custID = custid, @RoleID = roleid
	FROM	bodb02.dbo.custInfo WITH(NOLOCK)
	WHERE  username = @UserName

	CREATE TABLE #userList(custID INT) -- member

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

	-- get data
	BEGIN
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


	INSERT INTO #match(matchID, homeID, awayID, leagueID)
	SELECT  matchid, homeid, awayid, leagueid
	FROM	bodb02.dbo.match WITH(NOLOCK)
	WHERE	eventdate >= @yesterday AND sporttype = @SportType and eventstatus = 'running'
			and leagueid IN ( SELECT x.LeagueID FROM #tmpLeague x)

	INSERT INTO #bettransm(refno, bettype, betteam, matchID, odds)
	SELECT  refno, bettype, betteam, matchid, odds
	FROM	bodb02.dbo.bettransm WITH(NOLOCK)
	WHERE	matchid IN (SELECT x.matchID FROM #match x) AND statusID = 0

	INSERT INTO  #tmpMainTicket (refno, stake, bettype, betteam, oddsspread)
	SELECT  refno, stake * actualrate, bettype, betteam, oddsspread
	FROM	rmBettrans rm WITH(NOLOCK)
	INNER JOIN bodb02.dbo.CustInfo ci WITH(NOLOCK) ON rm.custid = ci.custid
	LEFT JOIN rmCustomer mc WITH (NOLOCK) ON rm.custid = mc.custid
	WHERE	winlostdate >= @yesterday AND rm.custID > 0 AND matchid IN (29,38,376) AND statusID = 0 AND rm.currency <> 20
		AND bettype IN (SELECT x.bettype FROM #bettype x)
		AND refno IN (SELECT DISTINCT y.refno FROM #bettransm y)
		AND hdp2 IN (SELECT z.selection FROM #tmpSelection z)
		AND (ci.CustomerClass = @CustomerClass OR @CustomerClass IS NULL)
		AND ISNULL(mc.level, 0) IN (SELECT level FROM #level)
		AND ( rm.custid IN (SELECT ul.custID FROM #userList ul) OR @UserName = '')

	IF @ComboType IN (1,2,3,4,5,6)
		BEGIN
			IF @ComboType = 1 -- Mix parlay only
				DELETE #tmpMainTicket WHERE bettype = 29 AND  betteam <> N'1' OR (bettype = 29 AND betteam = N'1' AND oddsspread = 1)
				ELSE IF @ComboType = 2 -- Combo parlay only
					DELETE #tmpMainTicket WHERE bettype = 29 AND betteam = N'1'
					ELSE IF @ComboType = 3 -- GOF only
						DELETE #tmpMainTicket WHERE (bettype = 29 AND betteam <> N'1') OR (bettype = 29 AND betteam = N'1' AND (oddsspread <> 1 OR oddsspread IS NULL))
						ELSE IF @ComboType = 4  -- combined between mix parlay and GOF
							DELETE #tmpMainTicket WHERE bettype = 29 AND betteam <> N'1'
							ELSE IF @ComboType = 5  -- combined between combo parlay and GOF
								DELETE #tmpMainTicket WHERE bettype = 29 AND  betteam = N'1' AND (oddsspread <> 1 OR oddsspread IS NULL)
								ELSE IF @ComboType = 6  -- combined between mix parlay and combo parlay
									DELETE #tmpMainTicket WHERE bettype = 29 AND  betteam = N'1' AND oddsspread = 1
		END


	END

	IF @isViewDetail = 0
	BEGIN	 
		INSERT INTO #Result (leagueID, HomeTotalStake, HomeTotalTicket, AwayTotalStake, AwayTotalTicket, OtherTotalStake, OtherTotalTicket)
		SELECT		m.leagueID, 
					SUM (CASE WHEN sub.betteam IN ('h','o','y') AND z.bettype IS NOT NULL THEN main.stake ELSE 0 END)		HomeTotalStake,
					SUM (CASE WHEN sub.betteam IN ('h','o','y') AND z.bettype IS NOT NULL THEN 1 ELSE 0 END)				HomeTotalTicket,
					SUM (CASE WHEN sub.betteam IN ('e','a','u','n') AND z.bettype IS NOT NULL THEN main.stake ELSE 0 END) AwayTotalStake,
					SUM (CASE WHEN sub.betteam IN ('e','a','u','n') AND z.bettype IS NOT NULL THEN 1 ELSE 0 END)			AwayTotalTicket,
					SUM (CASE WHEN sub.betteam NOT IN ('h','o','y','e','a','u','n')  OR z.bettype IS NULL THEN main.stake ELSE 0 END) OtherTotalStake,
					SUM (CASE WHEN sub.betteam NOT IN ('h','o','y','e','a','u','n')  OR z.bettype IS NULL THEN 1 ELSE 0 END)			OtherTotalTicket
		FROM		#tmpMainTicket main 
		INNER JOIN	#bettransm sub ON main.refno = sub.refno
		INNER JOIN	#match m ON sub.matchID = m.matchID
		LEFT JOIN   #bettype_selection z ON sub.bettype = z.bettype
		GROUP BY	m.leagueID

		;WITH cte AS 
		(
		SELECT	r.leagueID, l.leaguename ,HomeTotalStake, HomeTotalTicket, AwayTotalStake, AwayTotalTicket, OtherTotalStake, OtherTotalTicket, ROW_NUMBER() OVER(ORDER BY (HomeTotalStake + AwayTotalStake + OtherTotalStake) DESC)  AS rn
		FROM	#Result r
		INNER JOIN bodb02.dbo.League l ON r.leagueID = l.leagueid
		)
		SELECT leagueID, leaguename , HomeTotalStake, HomeTotalTicket, AwayTotalStake, AwayTotalTicket, OtherTotalStake, OtherTotalTicket
		FROM cte
		WHERE ( rn <= @limitRowCount OR @limitRowCount = 0)
		ORDER BY rn
	END
	ELSE
	BEGIN
		INSERT INTO #Details(matchID, bettype, odds, Stake, Ticket, betteam)
		SELECT 		sub.matchID, sub.bettype, AVG(sub.odds), SUM(main.stake),  COUNT(1), 
					sub.betteam
		FROM		#tmpMainTicket main 
		INNER JOIN	#bettransm sub ON main.refno = sub.refno
		GROUP BY	sub.matchID, sub.bettype, sub.betteam

		;WITH cte_data AS 
		(
			SELECT		d.matchID, 
						d.bettype bettype, 
						m.homeID,
						m.awayID,
						CASE WHEN SUM(CASE WHEN d.betteam IN ('h','o','y') THEN 1. ELSE 0 END) = 0 
							 THEN 0 ELSE SUM(CASE WHEN d.betteam IN ('h','o','y') THEN d.odds ELSE 0 END) / SUM(CASE WHEN d.betteam IN ('h','o','y')  THEN 1. ELSE 0 END) END home_avg_odds,
						CASE WHEN SUM(CASE WHEN d.betteam IN ('e','a','u','n') THEN 1. ELSE 0 END) = 0 
							 THEN 0 ELSE SUM(CASE WHEN d.betteam IN ('e','a','u','n') THEN d.odds ELSE 0 END) / SUM(CASE WHEN d.betteam IN ('e','a','u','n')  THEN 1. ELSE 0 END) END away_avg_odds,
						SUM(CASE WHEN d.betteam IN ('h','o','y') THEN d.Stake ELSE 0 END) home_total_stake,
						SUM(CASE WHEN d.betteam IN ('e','a','u','n') THEN d.Stake ELSE 0 END) away_total_stake,
						SUM(CASE WHEN d.betteam IN ('h','o','y') THEN d.Ticket ELSE 0 END) home_total_ticket,
						SUM(CASE WHEN d.betteam IN ('e','a','u','n') THEN d.Ticket ELSE 0 END) away_total_ticket,
						SUM(CASE WHEN d.betteam NOT IN ('h','o','y','e','a','u','n') THEN d.Stake ELSE 0 END) other_stake,
						SUM(CASE WHEN d.betteam NOT IN ('h','o','y','e','a','u','n') THEN d.Ticket ELSE 0 END) other_Ticket,
						CASE WHEN SUM(CASE WHEN d.betteam NOT IN ('h','o','y','e','a','u','n') THEN 1. ELSE 0 END) = 0 
							 THEN 0 ELSE SUM(CASE WHEN d.betteam NOT IN ('h','o','y','e','a','u','n') THEN d.odds ELSE 0 END) / SUM(CASE WHEN d.betteam NOT IN ('h','o','y','e','a','u','n')  THEN 1. ELSE 0 END) END other_avg_odds,
						SUM(d.Stake) AS total_stake,
						CASE WHEN d.betteam NOT IN ('h','o','y','e','a','u','n')  OR z.bettype IS NULL THEN 1 ELSE 0 END isOther
			FROM		#Details d
			INNER JOIN	#match m ON d.matchID = m.matchID
			LEFT JOIN   #bettype_selection z ON d.bettype = z.bettype
			GROUP BY	d.matchID,
						d.bettype,
						m.homeID,
						m.awayID,
						CASE WHEN d.betteam NOT IN ('h','o','y','e','a','u','n')  OR z.bettype IS NULL THEN 1 ELSE 0 END
		), sort AS
		(	
			SELECT x.matchID, ROW_NUMBER() OVER(ORDER BY (x.stake) DESC)  AS rn
			FROM
			(
				SELECT  matchID, 
						SUM(Stake) AS Stake
				FROM	#Details
				GROUP BY matchID
			) x
		)
		SELECT	d.matchID,
				h.teamname AS homeName, 
				ISNULL(b.typenamee,'Others') market,
				ISNULL(b.typeid,0) bettype,
				SUM(CASE WHEN d.isOther = 1 THEN d.other_avg_odds + d.home_avg_odds ELSE  d.home_avg_odds END) AS HomeAvgOdds,
				SUM(CASE WHEN d.isOther = 1  THEN d.other_stake + d.home_total_stake ELSE  d.home_total_stake END) AS HomeTotalStake,
				SUM(CASE WHEN d.isOther = 1  THEN d.other_ticket + home_total_ticket ELSE d.home_total_ticket END)  AS HomeTotalTicket,
				a.teamname AS awayName,
				SUM(d.away_avg_odds) AS AwayAvgOdds,
				SUM(d.away_total_stake) AS AwayTotalStake,
				SUM(d.away_total_ticket) AS AwayTotalTicket,
				d.isOther
		FROM  cte_data d 
		INNER JOIN sort r ON r.matchID = d.matchID
		INNER JOIN bodb02.dbo.Team h  WITH (NOLOCK) ON d.homeID = h.teamid
		INNER JOIN bodb02.dbo.Team a  WITH (NOLOCK) ON d.awayID = a.teamid
		LEFT JOIN #bettype_selection bs ON d.bettype = bs.bettype
		LEFT JOIN bodb02.dbo.bettype b WITH(NOLOCK) ON bs.bettype = b.typeid
		WHERE ( r.rn <= @limitRowCount OR @limitRowCount = 0)
		GROUP BY d.matchID, h.teamname, ISNULL(b.typenamee,'Others'), a.teamname, d.isOther, ISNULL(b.typeid,0)
		--ORDER BY r.rn
		
	END

	DROP TABLE #level
	DROP TABLE #tmpMainTicket
	DROP TABLE #match
	DROP TABLE #bettransm
	DROP TABLE #bettype
	DROP TABLE #bettype_selection
	DROP TABLE #Details
	DROP TABLE #Result
END
GO