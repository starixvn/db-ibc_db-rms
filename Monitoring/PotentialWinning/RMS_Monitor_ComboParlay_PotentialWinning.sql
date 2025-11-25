/*<info serverAlias="DBRMS-bodb_RMS" executers="wsv_rms" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[RMS_Monitor_ComboParlay_PotentialWinning]
	@selection		VARCHAR(MAX) = '',
	@sporttype		VARCHAR(100) = '',
	@level			VARCHAR(100) = '',
	@WinningAmount	MONEY = 0,
	@limitRowCount	INT = 100,
	@ParlayType		VARCHAR(100)  = '',
	@IsCornerParlay BIT = 0,
	@IsAgentView	BIT = 0,
	@Recommend		INT = NULL,
	@CustomerClass	SMALLINT = NULL,
	@company		VARCHAR(MAX) = '',
	@UserName		NVARCHAR(50) = ''
AS

/*
	Created: 20160427@Winnie
	DB: DBRMS-bodb_RMS
	Task: Monitoring Total Potential Winning by member

	Revisions:
		- 20170719@Winnie: Add MuayThai RedmineID: #79500
		- 20171219@Vicky: Add column currency [RedmineID: #88400]
		- 20190214@Jacob: Add Bet Builder RedmineID: #108694
		- 20200510@Percy: Add Penalty Shootout Combo [RedmineID: #133961]
		- 20201211@Danny: Monitor Corner Parlay Tickets [RedmineID: #146929]
		- 20201226@Sophia: Workaround for performance issue [RedmineID: #146929]
		- 20210218@Danny: Monitor Performance of GOF  [RedmineID: #149966]
		- 20210302@Danny: Changes on Potential Winning Monitor Tool [RedmineID: #146930]
		- 20210629@Danny: Add filtering by Customer Class[RedmineID: #156980]
		- 20210701@Danny: Track User Monitoring [RedmineID: #153875]
		- 20220519@Danny: add filter by Site AND username [RedmineID: #172691]
		- 20230420@Cherry: Add Site column (#186735)
		- 20231020@Cherry: Parlay Generator (#195498)
		- 20240102@Cherry: Parlay Type for Parlay Boost (#199217)
		- 20240115@Cherry: Change attribute for Parlay Generator (#199766)
		- 20240312@Cherry: Change SQL account in metadata (#202012)
		- 20241212@Cherry: Separate Cricket (#214664)
		- 20251016@Cherry: Move sites NovaCasino, SEAL888 from Deposit to Credit (#241763)
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
		
*/

BEGIN
	SET NOCOUNT ON

	CREATE TABLE #company(Site VARCHAR(50))
	INSERT INTO #company(Site)
	select value from  STRING_SPLIT(@company, ',')

	CREATE TABLE #level (level TINYINT)
	INSERT INTO #level (level)
	SELECT DISTINCT value FROM STRING_SPLIT(@level, ',')

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

		IF @IsAgentView = 0
		BEGIN
			IF @RoleID = 1 
				BEGIN
				INSERT INTO #userList (custID)
				SELECT	custid
				FROM	bodb02.dbo.custInfo WITH(NOLOCK)
				WHERE  custid = @custID AND roleid = 1
		END
		END
	END

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
			WHERE SportType NOT IN (1,2,3,4,5,6,7,8,9,11,43,44,50)
				AND SportType <= 99
	END

	-- get data
	BEGIN

		CREATE TABLE #bettrans_details(
			refno BIGINT, 
			bettype SMALLINT, 
			transid BIGINT,
			custID INT,
			username NVARCHAR(50),
			betteam NVARCHAR(10),
			CurrencyName NVARCHAR(50),
			Odds MONEY,
			stake MONEY,
			WinningAmount MONEY,
			CompanyLoseAmount MONEY,
			transdate DATETIME,
			recommend INT,
			level TINYINT,
			oddsspread SMALLMONEY,
			CustomerClass SMALLINT
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
		INSERT INTO #Generator(transid, bac)
		SELECT transid,
			TRY_CAST(TRY_CAST(ExtraInfo AS XML).value('(/p1/@bac)[1]', 'VARCHAR(50)') AS INT) 
		FROM dbo.rmBettrans WITH (NOLOCK)
		WHERE statusID = 0
			AND currency <> 20
			AND bettype = 29
			AND betteam = N'1'

		IF @Recommend > 0 and @IsAgentView = 0
		BEGIN
			
			CREATE TABLE #rmTransRecommend (transid BIGINT)

			INSERT INTO #rmTransRecommend(transid) 
			SELECT  transid FROM dbo.rmBettrans b WITH (NOLOCK) 
			WHERE recommend = @Recommend

			INSERT INTO #bettrans_details(refno,bettype,transid,custID,username,betteam,CurrencyName,Odds,stake,WinningAmount,CompanyLoseAmount, transdate,recommend,level,oddsspread, CustomerClass)
			SELECT	b.refno, 
					b.bettype, 
					b.transid,
					b.custID,
					b.username, 
					b.betteam, 
					b.CurrencyName,
					b.odds2 * b.TotalBet as Odds,
					b.stake * b.actualrate as stake,
					(b.odds2 - 1) * b.stake * b.actualrate as WinningAmount,
					(b.odds2 - 1) * b.stake * b.actualrate * (1 - b.tpositiontaking) as CompanyLoseAmount,
					b.transdate,
					b.recommend,
					ISNULL(mc.level,0),
					b.oddsspread,
					ci.CustomerClass
			FROM #rmTransRecommend tmp
				INNER JOIN dbo.rmBettrans b WITH (NOLOCK) ON tmp.transid = b.transid
				INNER JOIN #bettype bt ON b.bettype = bt.bettype
				INNER JOIN #tmpSelection s ON b.combo = s.selection
				INNER JOIN #tmpSport sp ON b.transid2 = sp.sporttype
				INNER JOIN bodb02.dbo.CustInfo ci WITH(NOLOCK) ON b.custid = ci.custid
				INNER JOIN bodb02.dbo.Customer ct WITH(NOLOCK) ON b.custid = ct.custid
				INNER JOIN #company cp ON cp.Site = ct.site
				LEFT JOIN rmCustomer mc WITH (NOLOCK) ON b.custid = mc.custid
				LEFT JOIN #Generator t ON t.transid = b.transid
			WHERE b.statusID = 0
				AND b.currency <> 20
				AND (ci.CustomerClass = @CustomerClass OR @CustomerClass IS NULL)
				AND	ISNULL(mc.level,0) IN (SELECT l.level FROM #level l)
				AND (b.bettype <> 29
					OR (EXISTS(SELECT TOP 1 1 FROM #ParlayType WHERE ParlayType = 1)
						AND b.bettype = 29 AND b.betteam = N'1' AND ISNULL(b.oddsspread,0) <> 3)
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
				AND (b.custid IN (SELECT ul.custID FROM #userList ul) OR @UserName = '')

			DROP TABLE #rmTransRecommend
		END
		ELSE
		BEGIN

			INSERT INTO #bettrans_details(refno,bettype,transid,custID,username,betteam,CurrencyName,Odds,stake,WinningAmount,CompanyLoseAmount, transdate,recommend,level,oddsspread, CustomerClass)
			SELECT	b.refno, 
					b.bettype, 
					b.transid,
					b.custID,
					b.username, 
					b.betteam, 
					b.CurrencyName,
					b.odds2 * b.TotalBet as Odds,
					b.stake * b.actualrate as stake,
					(b.odds2 - 1) * b.stake * b.actualrate as WinningAmount,
					(b.odds2 - 1) * b.stake * b.actualrate * (1 - b.tpositiontaking) as CompanyLoseAmount,
					b.transdate,
					b.recommend,
					ISNULL(mc.level,0),
					b.oddsspread,
					ci.CustomerClass
			FROM dbo.rmBettrans b WITH (NOLOCK)
				INNER JOIN #bettype bt ON b.bettype = bt.bettype
				INNER JOIN #tmpSelection s ON b.combo = s.selection
				INNER JOIN #tmpSport sp ON b.transid2 = sp.sporttype
				INNER JOIN bodb02.dbo.CustInfo ci WITH(NOLOCK) ON b.custid = ci.custid
				INNER JOIN bodb02.dbo.Customer ct WITH(NOLOCK) ON b.custid = ct.custid
				INNER JOIN #company cp ON cp.Site = ct.site
				LEFT JOIN rmCustomer mc WITH (NOLOCK) ON b.custid = mc.custid
				LEFT JOIN #Generator t ON t.transid = b.transid
			WHERE b.statusID = 0
				AND b.currency <> 20
				AND (ci.CustomerClass = @CustomerClass OR @CustomerClass IS NULL)
				AND	ISNULL(mc.level,0) IN(SELECT l.level FROM #level l)
				AND (b.bettype <> 29
					OR (EXISTS(SELECT TOP 1 1 FROM #ParlayType WHERE ParlayType = 1)
						AND b.bettype = 29 AND b.betteam = N'1' AND ISNULL(b.oddsspread,0) <> 3)
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
				AND (b.custid IN (SELECT ul.custID FROM #userList ul) OR @UserName = '')
		END

		IF @IsCornerParlay = 1
		BEGIN
			CREATE TABLE #bettransm(
			transid BIGINT,
			CornerParlay INT
			)

			INSERT INTO #bettransm (transid, CornerParlay)
			SELECT b.transid, COUNT(1) AS CornerParlay
			FROM #bettrans_details b WITH(NOLOCK)
			INNER JOIN  bodb02.dbo.bettransm bm WITH (NOLOCK) ON b.refno = bm.refno
			INNER JOIN bodb02.dbo.match m WITH (NOLOCK) ON bm.matchid = m.matchid
			WHERE m.ChildMatchType = 204
			GROUP BY b.transid 	 	


			INSERT INTO #bettransm (transid, CornerParlay)
			SELECT  b.transid, COUNT(1) AS CornerParlay
			FROM #bettrans_details b WITH(NOLOCK)
			INNER JOIN  bodb02.dbo.bettransm14 bm WITH (NOLOCK) ON b.refno = bm.refno
			INNER JOIN bodb02.dbo.match m WITH (NOLOCK) ON bm.matchid = m.matchid
			WHERE m.ChildMatchType = 204
			GROUP BY b.transid 		

			SELECT	transid, SUM(CornerParlay) CornerParlay
			INTO	#bettransmSummary
			FROM	#bettransm
			GROUP BY transid
			
			CREATE CLUSTERED INDEX #cix_bettransmSummary ON #bettransmSummary (transid)

			DELETE t
			FROM #bettrans_details t
			WHERE  NOT EXISTS (SELECT 1 FROM #bettransmSummary x WHERE  x.transid = t.transid)

			DROP TABLE #bettransm

		END

		DROP TABLE #bettype
		DROP TABLE #tmpSelection
		DROP TABLE #tmpSport
		
	END
	-- Return data
	BEGIN
		IF @IsAgentView = 0
		BEGIN

		IF @Recommend > 0 
		BEGIN
			SET @limitRowcount = 1000000
		END
			SELECT TOP(@limitRowcount) 
				MAX(b.transdate) AS transdate
				,b.custid
				,CASE WHEN s.isDeposit = 0 OR s.site IN ('Saba789','NovaCasino','SEAL888') THEN 'C' ELSE 'L' END SiteGroup
				,b.username
				,AVG(b.Odds) AS Odds
				,SUM(b.stake) AS stake
				,SUM(b.WinningAmount) AS WinningAmount
				,SUM(b.CompanyLoseAmount) AS CompanyLoseAmount
				,COUNT(1) AS TotalBets
				,b.level  AS level
				,b.CurrencyName AS currency
				,b.CustomerClass
				,SUM(CASE WHEN l.transid IS NOT NULL THEN 1 ELSE 0 END)  AS TotalTrackingBets
			FROM #bettrans_details b WITH(NOLOCK)
				LEFT JOIN dbo.rmUserTrackingLog l WITH(NOLOCK) ON b.transid = l.transid
				LEFT JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON b.custID = c.custid
				LEFT JOIN bodb02.dbo.Site s WITH(NOLOCK) ON c.site = s.site
			GROUP BY
				b.custid
				,b.username 
				,b.level 
				,b.CurrencyName
				,b.CustomerClass
				,CASE WHEN s.isDeposit = 0 OR s.site IN ('Saba789','NovaCasino','SEAL888') THEN 'C' ELSE 'L' END
			HAVING SUM(b.WinningAmount) >= CASE WHEN @Recommend >0 THEN 0 ELSE @WinningAmount END
			ORDER BY WinningAmount DESC
		
		END
		ELSE
		BEGIN
			SELECT TOP (@limitRowcount)
				CASE WHEN s.isDeposit = 0 OR s.site IN ('Saba789','NovaCasino','SEAL888') THEN 'C' ELSE 'L' END SiteGroup
				,mc.username AgentName
				,SUM(stake) TotalStake
				,SUM(b.WinningAmount) AS WinningAmount
				,COUNT(DISTINCT b.custid) TotalMember
				,b.recommend
			FROM  #bettrans_details b WITH(NOLOCK) 
				LEFT JOIN bodb02.dbo.custInfo  mc WITH (NOLOCK)  ON b.recommend = mc.custid
				LEFT JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON b.recommend = c.custid
				LEFT JOIN bodb02.dbo.Site s WITH(NOLOCK) ON c.site = s.site
			GROUP BY
				CASE WHEN s.isDeposit = 0 OR s.site IN ('Saba789','NovaCasino','SEAL888') THEN 'C' ELSE 'L' END 
				,mc.username
				,b.recommend
			HAVING SUM(b.WinningAmount) >= @WinningAmount
			ORDER BY WinningAmount DESC
			
		END

	END
	
	DROP TABLE #bettrans_details
	DROP TABLE #ParlayType

END
GO