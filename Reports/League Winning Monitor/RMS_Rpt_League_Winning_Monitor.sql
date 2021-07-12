/*<info serverAlias="DBRMS-bodb_RMS" executers="bodbRMSNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[RMS_Rpt_League_Winning_Monitor]
	@selection		VARCHAR(MAX) = '0'
	,@ParlayType	VARCHAR(20) = ''
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
		)

		CREATE TABLE #Result
		(
			leagueid			INT
			,custid				INT
			,transid			BIGINT
			,bettype			INT
		)


		DECLARE  @bettype TABLE (bettype SMALLINT)

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
			INSERT INTO @bettype (bettype)
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
			INSERT INTO @bettype (bettype)
			VALUES (38)

		-- Penalty shootout combo
		IF ',' + @ParlayType + ',' LIKE '%,4,%'
			INSERT INTO @bettype (bettype)
			VALUES (376)

		
		IF @CustID <>0 
		BEGIN
			DECLARE @recommend INT 
			SELECT @recommend = recommend FROM bodb02.dbo.Customer WITH(NOLOCK) WHERE custid = @CustID

			;WITH t AS
			(
					SELECT b.transid
					FROM dbo.rmBettrans b WITH (NOLOCK)
						INNER JOIN @bettype bt ON b.bettype = bt.bettype
						INNER JOIN @tmpSelection s ON b.hdp2 = s.selection
						INNER JOIN @tmpSport sp ON b.transid2 = sp.sporttype
						LEFT JOIN rmCustomer mc WITH (NOLOCK) ON b.custid = mc.custid
					WHERE b.recommend >= @recommend
						AND b.statusID = 0
						AND b.currency <> 20
						AND ISNULL(mc.level, 0) IN (SELECT level FROM @levelTab)
			)
			INSERT INTO  #bettrans (transid, matchid, refno, bettype, betteam, oddsspread, custid)
			SELECT	    b.transid, b.matchid, b.refno, b.bettype, b.betteam, b.oddsspread, b.custid
			FROM		t
			INNER JOIN	dbo.rmBettrans b WITH (NOLOCK) ON t.transid = b.transid
		END
		ELSE
		BEGIN
			DECLARE @min_transid BIGINT
			SELECT  @min_transid = MIN(transid) FROM dbo.rmBettrans WITH (NOLOCK) WHERE statusID = 0

			INSERT INTO #bettrans (transid, matchid, refno, bettype, betteam, oddsspread, custid)
			SELECT b.transid, b.matchid, b.refno,b.bettype,  b.betteam, b.oddsspread, b.custid
			FROM dbo.rmBettrans b WITH (NOLOCK)
				INNER JOIN @bettype bt ON b.bettype = bt.bettype
				INNER JOIN @tmpSelection s ON b.hdp2 = s.selection
				INNER JOIN @tmpSport sp ON b.transid2 = sp.sporttype
				LEFT JOIN rmCustomer mc WITH (NOLOCK) ON b.custid = mc.custid
			WHERE b.transid >= @min_transid
				AND b.statusID = 0
				AND b.currency <> 20
				AND ISNULL(mc.level, 0) IN (SELECT level FROM @levelTab)
		END
		IF @ComboType IN (1,2,3,4,5,6)
		BEGIN
			CREATE CLUSTERED INDEX CIX_bettype ON #bettrans (bettype)
			IF @ComboType = 1 -- Mix parlay only
				DELETE #bettrans WHERE bettype = 29 AND  betteam <> N'1' OR (bettype = 29 AND betteam = N'1' AND oddsspread = 1)
				ELSE IF @ComboType = 2 -- Combo parlay only
					DELETE #bettrans WHERE bettype = 29 AND betteam = N'1'
					ELSE IF @ComboType = 3 -- GOF only
						DELETE #bettrans WHERE (bettype = 29 AND betteam <> N'1') OR (bettype = 29 AND betteam = N'1' AND (oddsspread <> 1 OR oddsspread IS NULL))
						ELSE IF @ComboType = 4  -- combined between mix parlay and GOF
							DELETE #bettrans WHERE bettype = 29 AND betteam <> N'1'
							ELSE IF @ComboType = 5  -- combined between combo parlay and GOF
								DELETE #bettrans WHERE bettype = 29 AND  betteam = N'1' AND (oddsspread <> 1 OR oddsspread IS NULL)
								ELSE IF @ComboType = 6  -- combined between mix parlay and combo parlay
									DELETE #bettrans WHERE bettype = 29 AND  betteam = N'1' AND oddsspread = 1
		END

		IF EXISTS (SELECT 1 FROM #bettrans WHERE bettype IN (38, 376))
		BEGIN
			INSERT INTO #Result(leagueid, transid, bettype)
			SELECT m.leagueid, t.transid, t.bettype
			FROM #bettrans t
			INNER JOIN bodb02.dbo.match m WITH(NOLOCK) ON t.matchid = m.matchid
			WHERE t.bettype IN (38, 376) AND m.leagueid IN (SELECT x.LeagueId FROM #tmpLeague x)

		END

		IF EXISTS (SELECT 1 FROM #bettrans WHERE bettype IN (29))
		BEGIN
			INSERT INTO #Result(leagueid, transid, bettype, custid)
			SELECT u.leagueid, t.transid, t.bettype, t.custid
			FROM #bettrans t
			CROSS APPLY 
			(
				SELECT ma.leagueid 
				FROM bodb02.dbo.bettransm m WITH(NOLOCK)
				INNER JOIN bodb02.dbo.match ma WITH(NOLOCK) ON m.matchid = ma.matchid 
				WHERE m.refno = t.refno AND m.winlostdate > @MoveBetsDay OR m.winlostdate IS NULL
						
				UNION ALL
						
				SELECT ma.leagueid 
				FROM bodb02.dbo.bettransm14 m WITH(NOLOCK)
				INNER JOIN bodb02.dbo.match14 ma WITH(NOLOCK) ON m.matchid = ma.matchid 
				WHERE m.refno = t.refno AND m.winlostdate BETWEEN @BalanceUpDay AND @MoveBetsDay
					
				UNION ALL 

				SELECT ma.leagueid
				FROM dbo.rmBettransm_bk m WITH(NOLOCK)
				INNER JOIN dbo.rmMatch_bk ma WITH(NOLOCK) ON m.matchid = ma.matchid 
				WHERE m.refno = t.refno AND m.winlostdate < @BalanceUpDay 
				
			) u
			WHERE t.bettype = 29 AND u.leagueid IN  (SELECT x.LeagueId FROM #tmpLeague x)
		END

		DROP TABLE #tmpLeague
		DROP TABLE #bettrans
	END

	-- Return data
	BEGIN
	
		IF @ReportType = 1 AND  @LeagueID = 0 
		BEGIN
			;WITH t AS
			(
				SELECT	r.leagueid , 
						l.leagueName, 
						SUM(stake) AS totalStake, 
						SUM((rm.odds2 - 1) * rm.stake * rm.actualrate) AS totalWinningAmt, 
						SUM((rm.odds2 - 1) * rm.stake * rm.actualrate * (1 - rm.tpositiontaking)) AS companyLoseAmt, 
						COUNT(1) AS totalTicket 
				FROM	#Result r
				INNER JOIN rmBettrans rm ON r.transid = rm.transid
				INNER JOIN bodb02.dbo.League l ON r.leagueid = l.leagueid
				GROUP BY r.leagueid, l.leagueName
			), u AS
			(
				SELECT leagueid, leagueName, totalStake, totalWinningAmt, companyLoseAmt, totalTicket, ROW_NUMBER() OVER(ORDER BY totalWinningAmt DESC) AS rn
				FROM t
			)
			SELECT leagueid, leagueName, totalStake, totalWinningAmt, companyLoseAmt, totalTicket
			FROM u WHERE rn <= @limitRowCount
		END

		IF @ReportType = 2 AND @CustID = 0
		BEGIN
			;WITH t AS
			(
				SELECT	r.custid , 
						c.username, 
						SUM(stake) AS totalStake, 
						SUM((rm.odds2 - 1) * rm.stake * rm.actualrate) AS totalWinningAmt, 
						SUM((rm.odds2 - 1) * rm.stake * rm.actualrate * (1 - rm.tpositiontaking)) AS companyLoseAmt, 
						COUNT(1) AS totalTicket 
				FROM	#Result r
				INNER JOIN rmBettrans rm ON r.transid = rm.transid
				INNER JOIN bodb02.dbo.Customer c ON c.custid = r.custid
				GROUP BY r.custid, c.username
			), u AS
			(
				SELECT custid, username, totalStake, totalWinningAmt, companyLoseAmt, totalTicket, ROW_NUMBER() OVER(ORDER BY totalWinningAmt DESC) AS rn
				FROM t
			)
			SELECT custid, username, totalStake, totalWinningAmt, companyLoseAmt, totalTicket
			FROM u WHERE rn <= @limitRowCount
		END

		IF @CustID <> 0 OR @LeagueID <> 0
		BEGIN
			SELECT	rm.transdate,
					rm.transid,
					rm.Username,
					mc.level,
					rm.odds2 * rm.TotalBet AS odds,
					rm.stake,
					(rm.odds2 - 1) * rm.stake * rm.actualrate AS winningAmt,
					(rm.odds2 - 1) * rm.stake * rm.actualrate * (1 - rm.tpositiontaking) AS netWinAfterPT,
					(rm.odds2 - 1) * rm.stake * rm.actualrate * (1 - rm.tpositiontaking) AS companyLoseAmt,
					rm.combo,
					rm.hdp2 AS totalSelection,
					CASE WHEN transid2 NOT IN (-1,-3,1,2,3,4,5,6,7,8,9,11,43,44,-4,-5) THEN -2 ELSE rm.transid2 END AS Sporttype,
					rm.IP,
					rm.custid,
					rm.refno,
					rm.bettype
			FROM	#Result r
			INNER JOIN rmBettrans rm ON r.transid = rm.transid
			LEFT JOIN rmCustomer mc WITH (NOLOCK) ON r.custid = mc.custid
		END
	END
	DROP TABLE #Result
END
GO