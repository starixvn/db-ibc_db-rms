/*<info serverAlias="DBRMS-bodb_RMS" executers="bodbRMSNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[RMS_Monitor_EventPerformance_Detail]
	@selection		VARCHAR(MAX) = '',
	@leagueIDs		VARCHAR(MAX) = '',
	@ParlayType		VARCHAR(10)  = '',
	@level			VARCHAR(100) = '',
	@CustomerClass	SMALLINT = NULL,
	@SportType 		TINYINT = 43,
	@BetTypes		VARCHAR(MAX) = '',
	@UserName		NVARCHAR(50) = '',
	@matchid		INT, 
	@betChoice		TINYINT, -- 1 Home, 0 Away, 2: All, 3: Others
	@detailBettype	INT -- 0: Other
AS

/*
	Created: 20211221@Danny
	DB: DBRMS-bodb_RMS
	Task:  Monitor Performance for Event/Bettype/BetChoice (E-sports)

	Revisions:
		- 20220421@Danny: Init SP #170032
		- 20230130@Danny: Monitor detail Performance for Event/Bettype/BetChoice Soccer [RedmineID: #182724]
		- 20231020@Cherry: Parlay Generator (#195498)
		- 20240102@Cherry: Parlay Type for Parlay Boost (#199217)
		- 20240221@Cherry: Fix Stake as main report (#201133)

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
					. 7: Parlay Boost

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

	CREATE TABLE #tmpMainTicket(refno BIGINT, stake MONEY, bettype INT, betteam NVARCHAR(10), oddsspread MONEY, transid BIGINT)
	CREATE CLUSTERED INDEX cix_#tmpMainTicket ON #tmpMainTicket(refno)

	CREATE TABLE #match(matchID INT, homeID INT, awayID INT, leagueID INT)

	CREATE TABLE #bettransm (refno BIGINT, bettype INT, betteam NVARCHAR(10), matchID INT, odds SMALLMONEY)
	CREATE CLUSTERED INDEX cix_#bettransm ON #bettransm(refno)

	CREATE TABLE #bettype (bettype SMALLINT)
	CREATE TABLE #Result(leagueID INT, HomeTotalStake MONEY, AwayTotalStake MONEY, HomeTotalTicket INT, AwayTotalTicket INT, OtherTotalStake MONEY, OtherTotalTicket INT)
	CREATE TABLE #Details(teamID INT, matchID INT, bettype INT, odds SMALLMONEY, Stake MONEY, Ticket INT, betteam NVARCHAR(10), refno BIGINT, transid BIGINT)
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

	-- bettype selection
	CREATE TABLE #bettype_selection (bettype SMALLINT)
	INSERT INTO #bettype_selection(bettype)
	SELECT DISTINCT value FROM STRING_SPLIT(@BetTypes, ',')

	DECLARE @GroupID TINYINT
	SELECT @GroupID = GroupID
	FROM #bettype_list WHERE  bettype = @detailBettype

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

	CREATE TABLE #tmpBettrans (transid BIGINT, bact INT)
	INSERT INTO #tmpBettrans (transid, bact)
	SELECT transid,
		ISNULL(TRY_CAST(TRY_CAST(ExtraInfo AS XML).value('(/p1/@bact)[1]', 'VARCHAR(50)') AS INT),0)
	FROM rmBettrans WITH(NOLOCK)
	WHERE winlostdate >= @yesterday AND custID > 0 AND matchid IN (29,38,376) AND statusID = 0 AND currency <> 20
		AND bettype IN (SELECT bettype FROM #bettype)

	INSERT INTO #match(matchID, homeID, awayID, leagueID)
	SELECT  matchid, homeid, awayid, leagueid
	FROM	bodb02.dbo.match WITH(NOLOCK)
	WHERE	eventdate >= @yesterday AND sporttype = @SportType and eventstatus = 'running'
			and leagueid IN ( SELECT x.LeagueID FROM #tmpLeague x)

	INSERT INTO #bettransm(refno, bettype, betteam, matchID, odds)
	SELECT  refno, bettype, betteam, matchid, odds
	FROM	bodb02.dbo.bettransm WITH(NOLOCK)
	WHERE	matchid IN (SELECT x.matchID FROM #match x) AND statusID = 0

	INSERT INTO  #tmpMainTicket (refno, stake, bettype, betteam, oddsspread, transid)
	SELECT  refno, stake * actualrate, bettype, betteam, oddsspread, rm.transid
	FROM	rmBettrans rm WITH(NOLOCK)
		INNER JOIN bodb02.dbo.CustInfo ci WITH(NOLOCK) ON rm.custid = ci.custid
		LEFT JOIN rmCustomer mc WITH (NOLOCK) ON rm.custid = mc.custid
		LEFT JOIN #tmpBettrans t ON rm.transid = t.transid
	WHERE	winlostdate >= @yesterday AND rm.custID > 0 AND matchid IN (29,38,376) AND statusID = 0 AND rm.currency <> 20
		AND bettype IN (SELECT x.bettype FROM #bettype x)
		AND refno IN (SELECT DISTINCT y.refno FROM #bettransm y)
		AND hdp2 IN (SELECT z.selection FROM #tmpSelection z)
		AND (ci.CustomerClass = @CustomerClass OR @CustomerClass IS NULL)
		AND ISNULL(mc.level, 0) IN (SELECT level FROM #level)
		AND (rm.custid IN (SELECT ul.custID FROM #userList ul) OR @UserName = '')
		AND (rm.bettype <> 29
			OR (EXISTS(SELECT TOP 1 1 FROM #ParlayType WHERE ParlayType = 1)
				AND rm.bettype = 29 AND rm.betteam = N'1')
			OR (EXISTS(SELECT TOP 1 1 FROM #ParlayType WHERE ParlayType = 2)
				AND rm.bettype = 29 AND rm.betteam <> N'1')
			OR (EXISTS(SELECT TOP 1 1 FROM #ParlayType WHERE ParlayType = 5)
				AND rm.bettype = 29 AND rm.betteam = N'1' AND rm.oddsspread = 1)
			OR (EXISTS(SELECT TOP 1 1 FROM #ParlayType WHERE ParlayType = 6)
				AND rm.bettype = 29 AND rm.betteam = N'1' AND t.bact = 5)
			OR (EXISTS(SELECT TOP 1 1 FROM #ParlayType WHERE ParlayType = 7)
				AND rm.bettype = 29 AND rm.betteam = N'1' AND rm.oddsspread = 2)
			)			
	END

	INSERT INTO #Details(matchID, bettype, odds, Stake, Ticket, betteam, refno, transid)
	SELECT 		sub.matchID, sub.bettype, AVG(sub.odds), SUM(main.stake),  COUNT(1), sub.betteam, main.refno, main.transid
	FROM		#tmpMainTicket main 
	INNER JOIN	#bettransm sub ON main.refno = sub.refno
	GROUP BY	sub.matchID, sub.bettype, sub.betteam, main.refno,  main.transid

	IF @detailBettype <> 0
	BEGIN
		; WITH trans AS
		(
			SELECT DISTINCT transid 
			FROM #Details d
			WHERE matchID = @matchid 
			 AND bettype = @detailBettype
			 AND ( @betChoice = CASE WHEN d.betteam IN ('h','o','y','1') AND @GroupID = 1 THEN 1
									 WHEN d.betteam IN ('e','a','u','n','2') AND @GroupID = 1 THEN 0
									 WHEN d.betteam NOT IN ('h','o','y','1','e','a','u','n','2') OR  @GroupID <> 1 THEN 3
									 ELSE 0 
								END 
									
				OR @betChoice = 2
				)
		)
		SELECT
			rb.custid
			,rb.transdate
			,rb.transid
			,rb.username
			,CASE WHEN transid2 NOT IN (-1,-3,1,2,3,4,5,6,7,8,9,11,43,44,-4,-5) THEN -2 ELSE transid2 END AS Sporttype
			,rb.odds2 * rb.TotalBet AS odds
			,rb.statusID
			,rb.stake * rb.actualrate AS stake
			,(rb.odds2 - 1) * rb.stake * rb.actualrate * (1 - rb.tpositiontaking) AS maxpayout
			,rb.hdp2 AS TotalSelection
			,rb.TotalBet AS TotalBet
			,rb.IP
			,(rb.odds2 - 1) * rb.stake * rb.actualrate  AS potentialWinningAmt
			,ci.CustomerClass
			,rb.CurrencyName Currency
			,CASE WHEN rb.bettype = 29 AND rb.betteam = N'1' AND b.bact = 5 THEN 1 ELSE 0 END IsParlayGenerator
			,CASE WHEN rb.bettype = 29 AND rb.betteam = N'1' AND rb.oddsspread = 2 THEN 1 ELSE 0 END IsBoostBonus
		FROM rmBettrans rb WITH (NOLOCK)
			INNER JOIN trans t ON rb.transid = t.transid
			INNER JOIN bodb02.dbo.CustInfo ci WITH(NOLOCK) ON rb.custid = ci.custid
			LEFT JOIN rmCustomer mc WITH (NOLOCK) ON rb.custid = mc.custid
			LEFT JOIN #tmpBettrans b ON rb.transid = b.transid

	END
	ELSE 
	BEGIN
		SELECT	 d.bettype,  b.typenamee market,  SUM(d.odds) / SUM(Ticket)  AS AvgOdds  ,SUM(d.Stake) AS Stake, SUM(Ticket) Ticket
		FROM	#Details d
		INNER JOIN bodb02.dbo.bettype b WITH(NOLOCK) ON d.bettype = b.typeid
		WHERE	matchID = @matchid AND d.bettype NOT IN (SELECT x.bettype FROM #bettype_selection x)
		GROUP BY b.typenamee, d.bettype
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
END
GO