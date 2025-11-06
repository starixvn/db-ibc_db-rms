/*<info serverAlias="DBRMS-bodb_RMS" executers="wsv_rms" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[RMS_Rpt_League_Winning_Monitor]
	@selection		VARCHAR(MAX) = '0'
	,@ParlayType	VARCHAR(100) = ''
	,@sporttype		VARCHAR(100) = ''
	,@level			VARCHAR(100) = ''
	,@limitRowCount	INT = 100
	,@leagueGroupId INT = 99
	,@maxpayout		MONEY = 0
	,@ReportType	TINYINT = 1  --Group By League, Group By Username
	,@LeagueID		INT = 0 -- Details by League 
	,@CustID		INT = 0 -- Details by UserName
AS

/*
	Created: 20210628@Danny
	Task: Monitoring bets combo parlay of special members
	DB: DBRMS-bodb_RMS
	
	Revisions:
		- 20210628@Danny: Implement League Winning Monitor Report [RedmineID: #156982]
		- 20211111@Danny: Total Combo Bet data is incorrectly [RedmineID: #164563]
		- 20230420@Cherry: Add Site column (#186735)
		- 20231005@Cherry: Enhance code (#195077)
		- 20231020@Cherry: Parlay Generator (#195498)
		- 20240102@Cherry: Parlay Type for Parlay Boost (#199217)
		- 20240115@Cherry: Change attribute for Parlay Generator (#199766)
		- 20240312@Cherry: Change SQL account in metadata (#202012)
		- 20241106@Cherry: Add Single Match Parlay (#209293)
		- 20250115@Cherry: Support direct member (#215427)
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
					. '-4': Saba soccer
					. '-5': Saba basketball
		- @level:
					. '0': none
					. '1,2,3': level 1,2,3
		- @ReportType:
					. 1: Group by League
					. 2: Group by Username

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

	DECLARE @MBU TABLE (BalanceUpDay SMALLDATETIME, MoveBetsDay SMALLDATETIME)
	INSERT INTO @MBU (BalanceUpDay, MoveBetsDay)
	EXEC bodb02.dbo.Age_SelBalanceUpDay

	DECLARE @BalanceUpDay SMALLDATETIME, @MoveBetsDay SMALLDATETIME
	SELECT  @BalanceUpDay = BalanceUpDay, @MoveBetsDay = MoveBetsDay FROM @MBU

	DECLARE @levelTab TABLE (level TINYINT)
	INSERT INTO @levelTab (level)
	SELECT DISTINCT val FROM dbo.f_RMS_strSplit(@level, ',')
	-- selections
	BEGIN
		DECLARE  @tmpSelection TABLE  (selection INT)

		-- all selections (2 --> 100)
		IF ',' + @selection + ',' LIKE '%,0,%'
		BEGIN
			SELECT @selection = '2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,64,65,66,67,68,69,70,71,72,73,74,75,76,77,78,79,80,81,82,83,84,85,86,87,88,89,90,91,92,93,94,95,96,97,98,99,100'
		
			INSERT INTO @tmpSelection (selection)
			SELECT val FROM dbo.f_RMS_strSplit(@selection, ',')
		END
		-- 10UP (add 11 --> 100)
		ELSE IF ',' + @selection + ',' LIKE '%,10,%'
		BEGIN
			SELECT @selection = @selection + ',11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,64,65,66,67,68,69,70,71,72,73,74,75,76,77,78,79,80,81,82,83,84,85,86,87,88,89,90,91,92,93,94,95,96,97,98,99,100'
		
			INSERT INTO @tmpSelection (selection)
			SELECT val FROM dbo.f_RMS_strSplit(@selection, ',')
		END
		ELSE
		BEGIN
			INSERT INTO @tmpSelection (selection)
			SELECT val FROM dbo.f_RMS_strSplit(@selection, ',')
		END
	END

	-- sports
	BEGIN
		DECLARE  @tmpSport TABLE (sporttype INT)
		INSERT INTO @tmpSport (sporttype)
		SELECT val FROM dbo.f_RMS_strSplit(@sporttype, ',')

		IF ',' + @sporttype + ',' LIKE '%,-2,%'
			INSERT INTO @tmpSport (sporttype)
			SELECT SportType FROM bodb02.dbo.Sports WITH (NOLOCK)
			WHERE SportType NOT IN (1,2,3,4,5,6,7,8,9,11,43,44)
				AND SportType <= 99
	END

	-- League filter
	BEGIN
		CREATE TABLE #tmpLeague (LeagueId INT)
		IF @LeagueID <> 0 
		BEGIN
			INSERT INTO #tmpLeague (LeagueId) VALUES (@LeagueID)
		END
		ELSE
		BEGIN
			IF @leagueGroupId = 99
				INSERT INTO #tmpLeague (LeagueId)
				SELECT LeagueID FROM DBPRO.bodb02.dbo.ParlayLeagueMaxpayout WITH(NOLOCK) 
				WHERE	(LiveMaxPayout = @maxpayout OR NonLiveMaxPayout = @maxpayout OR @maxpayout = 0)

			IF @leagueGroupId <> 99
				INSERT INTO #tmpLeague (LeagueId)
				SELECT LeagueID FROM rmLeague WITH(NOLOCK) 
				WHERE  GroupID = @leagueGroupId
		END
	END

	-- get data
	BEGIN
		CREATE TABLE #bettrans
		(
			transid				BIGINT
			,refno				BIGINT
			,matchid			INT
			,bettype			SMALLINT
			,betteam			NVARCHAR(10)
			,oddsspread			SMALLMONEY
			,leagueid			INT
			,custid				INT
			,IsParlayGenerator  BIT
		)

		CREATE TABLE #tmpBettrans
		(
			transid BIGINT,
			bac INT
		)

		CREATE TABLE #Result
		(
			leagueid			INT
			,custid				INT
			,transid			BIGINT
			,bettype			INT
			,IsParlayGenerator  BIT
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

		
		IF @CustID <>0 
		BEGIN			

			INSERT INTO #tmpBettrans(transid, bac)
			SELECT transid,
				ISNULL(TRY_CAST(TRY_CAST(ExtraInfo AS XML).value('(/p1/@bac)[1]', 'VARCHAR(50)') AS INT),0)
			FROM 
				dbo.rmBettrans WITH (NOLOCK)
			WHERE custid = @CustID
				AND statusID = 0
				AND currency <> 20
				AND bettype = 29 
				AND betteam = N'1'

			INSERT INTO  #bettrans (transid, matchid, refno, bettype, betteam, oddsspread, custid, IsParlayGenerator)
			SELECT	    b.transid, b.matchid, b.refno, b.bettype, b.betteam, b.oddsspread, b.custid,
					CASE WHEN b.bettype = 29 AND b.betteam = N'1' AND t.bac|16 = t.bac THEN 1 ELSE 0 END
			FROM		dbo.rmBettrans b WITH (NOLOCK)
				INNER JOIN #bettype bt ON b.bettype = bt.bettype
				INNER JOIN @tmpSelection s ON b.hdp2 = s.selection
				INNER JOIN @tmpSport sp ON b.transid2 = sp.sporttype
				LEFT JOIN rmCustomer mc WITH (NOLOCK) ON b.custid = mc.custid
				LEFT JOIN #tmpBettrans t ON b.transid = t.transid
			WHERE 	  b.custid = @CustID
					AND b.statusID = 0
					AND b.currency <> 20
					AND ISNULL(mc.level, 0) IN (SELECT level FROM @levelTab)
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

		END
		ELSE
		BEGIN
			DECLARE @min_transid BIGINT
			SELECT  @min_transid = MIN(transid) FROM dbo.rmBettrans WITH (NOLOCK) WHERE statusID = 0

			INSERT INTO #tmpBettrans(transid, bac)
			SELECT transid,
				ISNULL(TRY_CAST(TRY_CAST(ExtraInfo AS XML).value('(/p1/@bac)[1]', 'VARCHAR(50)') AS INT),0)
			FROM 
				dbo.rmBettrans WITH (NOLOCK)
			WHERE transid >= @min_transid
				AND statusID = 0
				AND currency <> 20
				AND bettype = 29 
				AND betteam = N'1'

			INSERT INTO #bettrans (transid, matchid, refno, bettype, betteam, oddsspread, custid, IsParlayGenerator)
			SELECT b.transid, b.matchid, b.refno,b.bettype,  b.betteam, b.oddsspread, b.custid,
				CASE WHEN b.bettype = 29 AND b.betteam = N'1' AND t.bac|16 = t.bac THEN 1 ELSE 0 END
			FROM dbo.rmBettrans b WITH (NOLOCK)
				INNER JOIN #bettype bt ON b.bettype = bt.bettype
				INNER JOIN @tmpSelection s ON b.hdp2 = s.selection
				INNER JOIN @tmpSport sp ON b.transid2 = sp.sporttype
				LEFT JOIN rmCustomer mc WITH (NOLOCK) ON b.custid = mc.custid
				LEFT JOIN #tmpBettrans t ON b.transid = t.transid
			WHERE b.transid >= @min_transid
				AND b.statusID = 0
				AND b.currency <> 20
				AND ISNULL(mc.level, 0) IN (SELECT level FROM @levelTab)
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
		END		

		IF EXISTS (SELECT 1 FROM #bettrans WHERE bettype IN (38, 376))
		BEGIN
			INSERT INTO #Result(leagueid, custid, transid, bettype, IsParlayGenerator)
			SELECT m.leagueid, t.custid, t.transid, t.bettype, t.IsParlayGenerator
			FROM #bettrans t
				INNER JOIN bodb02.dbo.match m WITH(NOLOCK) ON t.matchid = m.matchid
			WHERE t.bettype IN (38, 376) AND m.leagueid IN (SELECT x.LeagueId FROM #tmpLeague x)

		END

		CREATE TABLE #tmpbettransm(refno BIGINT, LeagueID INT)
		CREATE TABLE #finalbettransm(refno BIGINT, LeagueID INT)

		INSERT INTO #tmpbettransm(refno, leagueID)
		SELECT m.refno, ma.leagueid 
		FROM bodb02.dbo.bettransm m WITH(NOLOCK)
			INNER JOIN bodb02.dbo.match ma WITH(NOLOCK) ON m.matchid = ma.matchid 
		WHERE m.refno IN (SELECT refno FROM #bettrans WHERE bettype = 29 )AND (m.winlostdate > @MoveBetsDay OR m.winlostdate IS NULL)
			AND ma.leagueid IN  (SELECT x.LeagueId FROM #tmpLeague x)
						
		INSERT INTO #tmpbettransm(refno, leagueID)				
		SELECT m.refno, ma.leagueid 
		FROM bodb02.dbo.bettransm14 m WITH(NOLOCK)
			INNER JOIN bodb02.dbo.match14 ma WITH(NOLOCK) ON m.matchid = ma.matchid 
		WHERE m.refno IN (SELECT refno FROM #bettrans WHERE bettype = 29 ) AND m.winlostdate BETWEEN @BalanceUpDay AND @MoveBetsDay
			AND ma.leagueid IN  (SELECT x.LeagueId FROM #tmpLeague x)
			
		INSERT INTO #tmpbettransm(refno, leagueID)
		SELECT m.refno, ma.leagueid 
		FROM dbo.rmBettransm_bk m WITH(NOLOCK)
			INNER JOIN dbo.rmMatch_bk ma WITH(NOLOCK) ON m.matchid = ma.matchid 
		WHERE m.refno IN (SELECT refno FROM #bettrans WHERE bettype = 29 ) AND m.winlostdate < @BalanceUpDay 
			AND ma.leagueid IN  (SELECT x.LeagueId FROM #tmpLeague x)

		INSERT INTO #finalbettransm(refno, leagueID)
		SELECT DISTINCT refno, leagueID
		FROM #tmpbettransm

		IF EXISTS (SELECT 1 FROM #bettrans WHERE bettype IN (29))
		BEGIN

			IF @ReportType = 1
			BEGIN
				INSERT INTO #Result(leagueid, transid, bettype, custid, IsParlayGenerator)
				SELECT u.leagueid, t.transid, t.bettype, t.custid, t.IsParlayGenerator
				FROM #bettrans t
					INNER JOIN #finalbettransm u ON t.refno = u.refno
				WHERE t.bettype = 29 AND u.leagueid IN  (SELECT x.LeagueId FROM #tmpLeague x)
			END

			IF @ReportType = 2
			BEGIN
				INSERT INTO #Result( transid, bettype, custid, IsParlayGenerator)
				SELECT DISTINCT t.transid, t.bettype, t.custid, t.IsParlayGenerator
				FROM #bettrans t
					INNER JOIN #finalbettransm u ON t.refno = u.refno
				WHERE t.bettype = 29 AND u.leagueid IN  (SELECT x.LeagueId FROM #tmpLeague x)
			END


		END

		DROP TABLE #tmpLeague
		DROP TABLE #bettrans
		DROP TABLE #tmpbettransm
		DROP TABLE #finalbettransm
		DROP TABLE #bettype
		DROP TABLE #ParlayType
	END

	-- Return data
	BEGIN
	
		IF @ReportType = 1 AND  @LeagueID = 0 
		BEGIN
			;WITH t AS
			(
				SELECT	r.leagueid , 
						l.leagueName, 
						SUM(rm.stake* rm.actualrate) AS totalStake, 
						SUM((rm.odds2 - 1) * rm.stake * rm.actualrate) AS totalWinningAmt, 
						SUM((rm.odds2 - 1) * rm.stake * rm.actualrate * (1 - rm.tpositiontaking)) AS companyLoseAmt, 
						COUNT(1) AS totalTicket,
						CASE
							WHEN rm.bettype = 29 AND rm.betteam = N'1' AND rm.oddsspread = 3 THEN 8
							WHEN rm.bettype = 29 AND rm.betteam = N'1' THEN 1
							WHEN rm.bettype = 29 AND rm.betteam <> N'1' THEN 2
							WHEN rm.bettype = 38 THEN 3
							WHEN rm.bettype = 376 THEN 4
						ELSE 0 END AS ParlayType						
				FROM #Result r
					INNER JOIN rmBettrans rm ON r.transid = rm.transid
					INNER JOIN bodb02.dbo.League l ON r.leagueid = l.leagueid
				GROUP BY r.leagueid, l.leagueName
			), u AS
			(
				SELECT leagueid, leagueName, totalStake, totalWinningAmt, companyLoseAmt, totalTicket, ParlayType,
					ROW_NUMBER() OVER(ORDER BY totalWinningAmt DESC) AS rn
				FROM t
			)
			SELECT leagueid, leagueName, totalStake, totalWinningAmt, companyLoseAmt, totalTicket, ParlayType
			FROM u WHERE rn <= @limitRowCount
		END

		IF @ReportType = 2 AND @CustID = 0
		BEGIN
			;WITH t AS
			(
				SELECT	r.custid , 
						CASE WHEN s.isDeposit = 0 OR s.site IN ('Saba789','NovaCasino','SEAL888') THEN 'C' ELSE 'L' END SiteGroup,
						c.username, 
						SUM(rm.stake * rm.actualrate)  AS totalStake, 
						SUM((rm.odds2 - 1) * rm.stake * rm.actualrate) AS totalWinningAmt, 
						SUM((rm.odds2 - 1) * rm.stake * rm.actualrate * (1 - rm.tpositiontaking)) AS companyLoseAmt, 
						COUNT(1) AS totalTicket,
						CASE
							WHEN rm.bettype = 29 AND rm.betteam = N'1' AND rm.oddsspread = 3 THEN 8
							WHEN rm.bettype = 29 AND rm.betteam = N'1' THEN 1
							WHEN rm.bettype = 29 AND rm.betteam <> N'1' THEN 2
							WHEN rm.bettype = 38 THEN 3
							WHEN rm.bettype = 376 THEN 4
						ELSE 0 END AS ParlayType
				FROM	#Result r
					INNER JOIN rmBettrans rm WITH(NOLOCK) ON r.transid = rm.transid
					LEFT JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON c.custid = r.custid
					LEFT JOIN bodb02.dbo.site s WITH(NOLOCK) ON c.site = s.site
				GROUP BY r.custid, c.username,
						CASE WHEN s.isDeposit = 0 OR s.site IN ('Saba789','NovaCasino','SEAL888') THEN 'C' ELSE 'L' END 
			), u AS
			(
				SELECT custid, SiteGroup, username, totalStake, totalWinningAmt, companyLoseAmt, totalTicket, ParlayType,
					ROW_NUMBER() OVER(ORDER BY totalWinningAmt DESC) AS rn
				FROM t
			)
			SELECT custid, SiteGroup, username, totalStake, totalWinningAmt, companyLoseAmt, totalTicket, ParlayType
			FROM u WHERE rn <= @limitRowCount
		END

		IF @CustID <> 0 OR @LeagueID <> 0
		BEGIN
			SELECT	rm.transdate,
					rm.transid,
					CASE WHEN s.isDeposit = 0 OR s.site IN ('Saba789','NovaCasino','SEAL888') THEN 'C' ELSE 'L' END SiteGroup,
					rm.Username,
					mc.level,
					rm.odds2 * rm.TotalBet AS odds,
					rm.stake * rm.actualrate as stake,
					(rm.odds2 - 1) * rm.stake * rm.actualrate AS winningAmt,
					(rm.odds2 - 1) * rm.stake * rm.actualrate * (1 - rm.tpositiontaking) AS companyLoseAmt,
					rm.TotalBet AS  combo,
					rm.hdp2 AS totalSelection,
					CASE WHEN transid2 NOT IN (-1,-3,1,2,3,4,5,6,7,8,9,11,43,44,-4,-5) THEN -2 ELSE rm.transid2 END AS Sporttype,
					rm.IP,
					rm.custid,
					rm.refno,
					rm.bettype, 
					r.IsParlayGenerator,
					CAST(CASE WHEN rm.bettype = 29 AND rm.betteam = N'1' AND rm.oddsspread = 2 THEN 1 ELSE 0 END AS BIT) AS IsBoostBonus,
					CASE
						WHEN rm.bettype = 29 AND rm.betteam = N'1' AND rm.oddsspread = 3 THEN 8
						WHEN rm.bettype = 29 AND rm.betteam = N'1' THEN 1
						WHEN rm.bettype = 29 AND rm.betteam <> N'1' THEN 2
						WHEN rm.bettype = 38 THEN 3
						WHEN rm.bettype = 376 THEN 4
					ELSE 0 END AS ParlayType
			FROM	#Result r
				INNER JOIN rmBettrans rm WITH(NOLOCK) ON r.transid = rm.transid
				LEFT JOIN rmCustomer mc WITH (NOLOCK) ON r.custid = mc.custid
				LEFT JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON r.custid = c.custid
				LEFT JOIN bodb02.dbo.site s WITH(NOLOCK) ON c.site = s.site
		END
	END
	DROP TABLE #Result
	DROP TABLE #tmpBettrans
END
GO