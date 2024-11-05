/*<info serverAlias="DBRMS-bodb_RMS" executers="wsv_rms" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[RMS_Monitor_EventPerformance_Summary]
	@selection		VARCHAR(MAX) = '',
	@leagueIDs		VARCHAR(MAX) = '',
	@ParlayType		VARCHAR(100)  = '',
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
		- 20230130@Danny: Monitor detail Performance for Event/Bettype/BetChoice Soccer [RedmineID: #182724]
		- 20230815@Cherry: Add Total Stake column (#192680)
		- 20231020@Cherry: Parlay Generator (#195498)
		- 20240115@Cherry: Change attribute for Parlay Generator (#199766)
		- 20240312@Cherry: Change SQL account in metadata (#202012)
		- 20240802@Cherry: Change formula of stake (#202238)
		- 20241031@Cherry: Add Single Match Parlay (#209293)
	
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
					. 6: Parlay Generator

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

	CREATE TABLE #tmpMainTicket(refno BIGINT, stake MONEY, bettype INT, betteam NVARCHAR(10), oddsspread MONEY, hdp2 SMALLMONEY)
	CREATE CLUSTERED INDEX cix_#tmpMainTicket ON #tmpMainTicket(refno)

	CREATE TABLE #match(matchID INT, homeID INT, awayID INT, leagueID INT)

	CREATE TABLE #bettransm (refno BIGINT, bettype INT, betteam NVARCHAR(10), matchID INT, odds SMALLMONEY)
	CREATE CLUSTERED INDEX cix_#bettransm ON #bettransm(refno)

	CREATE TABLE #bettype (bettype SMALLINT)
	CREATE TABLE #Result(leagueID INT, HomeTotalStake MONEY, AwayTotalStake MONEY, HomeTotalTicket INT, AwayTotalTicket INT, OtherTotalStake MONEY, OtherTotalTicket INT)
	CREATE TABLE #Details(teamID INT, matchID INT, bettype INT, odds SMALLMONEY, Stake MONEY, Ticket INT, betteam NVARCHAR(10))
	
	CREATE TABLE #tmpSMP (LeagueID INT, MatchID INT, Odds SMALLMONEY, Stake MONEY, Ticket INT)

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

	-- LeagueIDs
	BEGIN
		CREATE TABLE #tmpLeague (LeagueID INT)
		INSERT INTO #tmpLeague (LeagueID)
		SELECT value FROM STRING_SPLIT(@leagueIDs, ',')
	END

	-- #level
	CREATE TABLE #level (level TINYINT)
	INSERT INTO #level (level)
	SELECT DISTINCT value FROM STRING_SPLIT(@level, ',')

	-- bettype selection
	CREATE TABLE #bettype_list (bettype SMALLINT, bettypeName NVARCHAR(128), GroupID TINYINT)
	INSERT INTO #bettype_list(bettype,bettypeName,GroupID)
	EXEC RMS_BettypeSel @SportType = @SportType

	CREATE TABLE #bettype_selection (bettype SMALLINT, GroupID TINYINT)
	INSERT INTO #bettype_selection(bettype)
	SELECT DISTINCT value FROM STRING_SPLIT(@BetTypes, ',')

	UPDATE t
	SET t.GroupID = u.GroupID
	FROM #bettype_selection t
	INNER JOIN #bettype_list u ON t.bettype = u.bettype

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
		CREATE TABLE #ParlayType (ParlayType SMALLINT)

		INSERT INTO #ParlayType (ParlayType)
			SELECT	value
			FROM STRING_SPLIT(@ParlayType, ',')
			
		IF EXISTS(SELECT TOP 1 1 FROM #ParlayType WHERE ParlayType = 1) AND
			NOT EXISTS(SELECT TOP 1 1 FROM #ParlayType WHERE ParlayType = 6)
			INSERT INTO #ParlayType (ParlayType) VALUES (6)
		
		IF ',' + @ParlayType + ',' LIKE '%,1,%' OR ',' + @ParlayType + ',' LIKE '%,2,%' OR ',' + @ParlayType + ',' LIKE '%,5,%' OR ',' + @ParlayType + ',' LIKE '%,6,%'
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


	INSERT INTO #match(matchID, homeID, awayID, leagueID)
	SELECT  matchid, homeid, awayid, leagueid
	FROM	bodb02.dbo.match WITH(NOLOCK)
	WHERE	eventdate >= @yesterday AND sporttype = @SportType and eventstatus = 'running'
			and leagueid IN ( SELECT x.LeagueID FROM #tmpLeague x)

	INSERT INTO #bettransm(refno, bettype, betteam, matchID, odds)
	SELECT  refno, bettype, betteam, matchid, odds
	FROM	bodb02.dbo.bettransm WITH(NOLOCK)
	WHERE	matchid IN (SELECT x.matchID FROM #match x) AND statusID = 0

	CREATE TABLE #tmpBettrans (transid BIGINT, bac INT)
	INSERT INTO #tmpBettrans (transid, bac)
	SELECT transid,
		ISNULL(TRY_CAST(TRY_CAST(ExtraInfo AS XML).value('(/p1/@bac)[1]', 'VARCHAR(50)') AS INT),0)
	FROM rmBettrans WITH(NOLOCK)
	WHERE winlostdate >= @yesterday AND custID > 0 AND matchid = 29 AND statusID = 0 AND currency <> 20
		AND bettype IN (SELECT bettype FROM #bettype)

	INSERT INTO  #tmpMainTicket (refno, stake, bettype, betteam, oddsspread, hdp2)
	SELECT  refno, stake * actualrate, bettype, betteam, oddsspread, hdp2
	FROM	rmBettrans rm WITH(NOLOCK)
		INNER JOIN bodb02.dbo.CustInfo ci WITH(NOLOCK) ON rm.custid = ci.custid
		LEFT JOIN rmCustomer mc WITH (NOLOCK) ON rm.custid = mc.custid
		LEFT JOIN #tmpBettrans t ON rm.transid = t.transid
	WHERE	winlostdate >= @yesterday AND rm.custID > 0 AND matchid = 29 AND statusID = 0 AND rm.currency <> 20
		AND bettype IN (SELECT x.bettype FROM #bettype x)
		AND refno IN (SELECT DISTINCT y.refno FROM #bettransm y)
		AND hdp2 IN (SELECT z.selection FROM #tmpSelection z)
		AND (ci.CustomerClass = @CustomerClass OR @CustomerClass IS NULL)
		AND ISNULL(mc.level, 0) IN (SELECT level FROM #level)
		AND ( rm.custid IN (SELECT ul.custID FROM #userList ul) OR @UserName = '')
		AND ((EXISTS(SELECT TOP 1 1 FROM #ParlayType WHERE ParlayType = 1)
				AND rm.bettype = 29 AND rm.betteam = N'1')
			OR (EXISTS(SELECT TOP 1 1 FROM #ParlayType WHERE ParlayType = 2)
				AND rm.bettype = 29 AND rm.betteam <> N'1')
			OR (EXISTS(SELECT TOP 1 1 FROM #ParlayType WHERE ParlayType = 5)
				AND rm.bettype = 29 AND rm.betteam = N'1' AND rm.oddsspread = 1)
			OR (EXISTS(SELECT TOP 1 1 FROM #ParlayType WHERE ParlayType = 6)
				AND rm.bettype = 29 AND rm.betteam = N'1' AND t.bac|16 = t.bac)
			)		
	END

	IF EXISTS(SELECT 1 FROM #bettype WHERE bettype = 38)
	BEGIN
		INSERT INTO #tmpSMP (LeagueID, MatchID, Odds, Stake, Ticket)
		SELECT  m.leagueID, 
				m.matchID,
				AVG(rm.odds),
				SUM(rm.stake * rm.actualrate),
				COUNT(1)
		FROM	rmBettrans rm WITH(NOLOCK)
			INNER JOIN #match m ON rm.matchid = m.matchID
			INNER JOIN bodb02.dbo.CustInfo ci WITH(NOLOCK) ON rm.custid = ci.custid
			LEFT JOIN rmCustomer mc WITH (NOLOCK) ON rm.custid = mc.custid
		WHERE	rm.winlostdate >= @yesterday 
			AND rm.custID > 0 
			AND statusID = 0 
			AND rm.currency <> 20
			AND rm.bettype = 38
			AND rm.hdp2 IN (SELECT z.selection FROM #tmpSelection z)
			AND (ci.CustomerClass = @CustomerClass OR @CustomerClass IS NULL)
			AND ISNULL(mc.level, 0) IN (SELECT level FROM #level)
			AND (rm.custid IN (SELECT ul.custID FROM #userList ul) OR @UserName = '')
		GROUP BY m.leagueID, m.matchID
	END

	IF @isViewDetail = 0
	BEGIN	 
		INSERT INTO #Result (leagueID, HomeTotalStake, HomeTotalTicket, AwayTotalStake, AwayTotalTicket, OtherTotalStake, OtherTotalTicket)
		SELECT LeagueID, 
			SUM(HomeTotalStake), 
			SUM(HomeTotalTicket), 
			SUM(AwayTotalStake), 
			SUM(AwayTotalTicket), 
			SUM(OtherTotalStake), 
			SUM(OtherTotalTicket)
		FROM (
		SELECT		m.leagueID, 
					SUM (CASE WHEN sub.betteam IN ('h','o','y','1') AND z.bettype IS NOT NULL AND z.GroupID = 1 THEN main.stake/main.hdp2 ELSE 0 END)		HomeTotalStake,
					SUM (CASE WHEN sub.betteam IN ('h','o','y','1') AND z.bettype IS NOT NULL AND z.GroupID = 1 THEN 1 ELSE 0 END)				HomeTotalTicket,
					SUM (CASE WHEN sub.betteam IN ('e','a','u','n','2') AND z.bettype IS NOT NULL AND z.GroupID = 1  THEN main.stake/main.hdp2 ELSE 0 END) AwayTotalStake,
					SUM (CASE WHEN sub.betteam IN ('e','a','u','n','2') AND z.bettype IS NOT NULL AND z.GroupID = 1  THEN 1 ELSE 0 END)			AwayTotalTicket,
					SUM (CASE WHEN sub.betteam NOT IN ('h','o','y','e','a','u','n','1','2')  OR z.bettype IS NULL OR z.GroupID <> 1 THEN main.stake/main.hdp2 ELSE 0 END) OtherTotalStake,
					SUM (CASE WHEN sub.betteam NOT IN ('h','o','y','e','a','u','n','1','2')  OR z.bettype IS NULL OR z.GroupID <> 1  THEN 1 ELSE 0 END) OtherTotalTicket
		FROM		#tmpMainTicket main 
			INNER JOIN	#bettransm sub ON main.refno = sub.refno
			INNER JOIN	#match m ON sub.matchID = m.matchID
			LEFT JOIN   #bettype_selection z ON sub.bettype = z.bettype
		GROUP BY	m.leagueID
		UNION ALL 
		SELECT LeagueID, 
		0 HomeTotalStake, 
		0 HomeTotalTicket, 
		0 AwayTotalStake, 
		0 AwayTotalTicket, 
		SUM(Stake) OtherTotalStake, 
		SUM(Ticket) OtherTotalTicket
		FROM #tmpSMP
		GROUP BY LeagueID
		) t
		GROUP BY LeagueID		

		;WITH cte AS 
		(
		SELECT	r.leagueID, l.leaguename ,HomeTotalStake, HomeTotalTicket, AwayTotalStake, AwayTotalTicket, OtherTotalStake, OtherTotalTicket, ROW_NUMBER() OVER(ORDER BY (HomeTotalStake + AwayTotalStake + OtherTotalStake) DESC)  AS rn
		FROM	#Result r
			INNER JOIN bodb02.dbo.League l WITH(NOLOCK) ON r.leagueID = l.leagueid
		)
		SELECT leagueID, leaguename , HomeTotalStake, HomeTotalTicket, AwayTotalStake, AwayTotalTicket, OtherTotalStake, OtherTotalTicket
		FROM cte
		WHERE ( rn <= @limitRowCount OR @limitRowCount = 0)
		ORDER BY rn
	END
	ELSE
	BEGIN
		INSERT INTO #Details(matchID, bettype, odds, Stake, Ticket, betteam)
		SELECT MatchID,
			bettype,
			AVG(Odds),
			SUM(Stake),
			SUM(Ticket),
			betteam
		FROM (
		SELECT 	sub.matchID, 
				sub.bettype, 
				AVG(sub.odds) Odds, 
				SUM(main.stake/main.hdp2) Stake,  
				COUNT(1) Ticket, 
				sub.betteam
		FROM		#tmpMainTicket main 
			INNER JOIN	#bettransm sub ON main.refno = sub.refno
		GROUP BY	sub.matchID, sub.bettype, sub.betteam
		UNION ALL
		SELECT m.MatchID,
			38 bettype,
			m.Odds,
			m.Stake,
			m.Ticket,
			'1' betteam
		FROM #tmpSMP m
		) t
		GROUP BY MatchID, bettype, betteam

		;WITH cte_data AS 
		(
			SELECT		l.leaguename,
						d.matchID, 
						d.bettype bettype, 
						m.homeID,
						m.awayID,
						CASE WHEN SUM(CASE WHEN d.betteam IN ('h','o','y','1') AND z.GroupID = 1 THEN 1. ELSE 0 END) = 0 
							 THEN 0 ELSE SUM(CASE WHEN d.betteam IN ('h','o','y','1') AND z.GroupID = 1 THEN d.odds ELSE 0 END) / SUM(CASE WHEN d.betteam IN ('h','o','y','1') AND z.GroupID = 1 THEN 1. ELSE 0 END) END home_avg_odds,
						CASE WHEN SUM(CASE WHEN d.betteam IN ('e','a','u','n','2') AND z.GroupID = 1 THEN 1. ELSE 0 END) = 0 
							 THEN 0 ELSE SUM(CASE WHEN d.betteam IN ('e','a','u','n','2') AND z.GroupID = 1 THEN d.odds ELSE 0 END) / SUM(CASE WHEN d.betteam IN ('e','a','u','n','2') AND z.GroupID = 1 THEN 1. ELSE 0 END) END away_avg_odds,
						SUM(CASE WHEN d.betteam IN ('h','o','y','1') AND z.GroupID = 1 THEN d.Stake ELSE 0 END) home_total_stake,
						SUM(CASE WHEN d.betteam IN ('e','a','u','n','2') AND z.GroupID = 1 THEN d.Stake ELSE 0 END) away_total_stake,
						SUM(CASE WHEN d.betteam IN ('h','o','y','1')  AND z.GroupID = 1 THEN d.Ticket ELSE 0 END) home_total_ticket,
						SUM(CASE WHEN d.betteam IN ('e','a','u','n','2') AND z.GroupID = 1 THEN d.Ticket ELSE 0 END) away_total_ticket,
						SUM(CASE WHEN d.betteam NOT IN ('h','o','y','e','a','u','n','1') OR z.GroupID <> 1 OR z.bettype IS NULL OR d.bettype = 38 THEN d.Stake ELSE 0 END) other_stake,
						SUM(CASE WHEN d.betteam NOT IN ('h','o','y','e','a','u','n','2') OR z.GroupID <> 1 OR z.bettype IS NULL OR d.bettype = 38 THEN d.Ticket ELSE 0 END) other_Ticket,
						CASE WHEN SUM(CASE WHEN d.betteam NOT IN ('h','o','y','e','a','u','n','1','2') OR z.GroupID <> 1 OR z.bettype IS NULL THEN 1. ELSE 0 END) = 0 
							 THEN 0 ELSE SUM(CASE WHEN d.betteam NOT IN ('h','o','y','e','a','u','n','1','2') OR z.GroupID <> 1 OR z.bettype IS NULL OR d.bettype = 38 THEN d.odds ELSE 0 END) / SUM(CASE WHEN d.betteam NOT IN ('h','o','y','e','a','u','n','1','2') OR z.GroupID <> 1 OR z.bettype IS NULL OR d.bettype = 38 THEN 1. ELSE 0 END) END other_avg_odds,
						SUM(d.Stake) AS total_stake,
						CASE WHEN d.betteam NOT IN ('h','o','y','e','a','u','n','1','2') OR z.bettype IS NULL OR z.GroupID <> 1 OR d.bettype = 38 THEN 1 ELSE 0 END isOther
			FROM		#Details d
				INNER JOIN	#match m ON d.matchID = m.matchID
				INNER JOIN bodb02.dbo.League l WITH(NOLOCK) ON m.leagueID = l.leagueid
				LEFT JOIN #bettype_selection z ON d.bettype = z.bettype
			GROUP BY	l.leaguename,
						d.matchID,
						d.bettype,
						m.homeID,
						m.awayID,
						CASE WHEN d.betteam NOT IN ('h','o','y','e','a','u','n','1','2') OR z.bettype IS NULL OR z.GroupID <> 1 OR d.bettype = 38 THEN 1 ELSE 0 END

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
		SELECT	d.leaguename,				
				d.matchID,
				h.teamname AS homeName, 
				ISNULL(b.typenamee,'Others') market,
				CASE WHEN d.bettype = 38 THEN d.bettype
					ELSE ISNULL(b.typeid,0) 
				END bettype,
				SUM(CASE WHEN d.isOther = 1 THEN d.other_avg_odds + d.home_avg_odds ELSE d.home_avg_odds END) AS HomeAvgOdds,
				SUM(CASE WHEN d.isOther = 1 THEN d.other_stake + d.home_total_stake ELSE d.home_total_stake END) AS HomeTotalStake,
				SUM(CASE WHEN d.isOther = 1 THEN d.other_ticket + home_total_ticket ELSE d.home_total_ticket END)  AS HomeTotalTicket,
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
		WHERE (r.rn <= @limitRowCount OR @limitRowCount = 0)
		GROUP BY d.leaguename, d.matchID, 
				h.teamname, 
				a.teamname, d.isOther, 
				ISNULL(b.typenamee,'Others'),
				CASE WHEN d.bettype = 38 THEN d.bettype
					ELSE ISNULL(b.typeid,0) 
				END
		
	END

	DROP TABLE #level
	DROP TABLE #tmpMainTicket
	DROP TABLE #match
	DROP TABLE #bettransm
	DROP TABLE #bettype
	DROP TABLE #bettype_selection
	DROP TABLE #Details
	DROP TABLE #Result
	DROP TABLE #ParlayType
	DROP TABLE #tmpBettrans
	DROP TABLE #tmpSMP
	DROP TABLE #bettype_list
	DROP TABLE #tmpLeague
	DROP TABLE #tmpSelection
	DROP TABLE #userList
END
GO