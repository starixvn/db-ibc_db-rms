/*<info serverAlias="DBRMS-bodb_RMS" executers="bodbRMSNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[RMS_Monitor_ComboParlay_Betlist]
	@selection		VARCHAR(MAX) = '0',
	@sporttype		VARCHAR(100) = '',
	@level			VARCHAR(100) = '',
	@Market			VARCHAR(100) = '',
	@stake			MONEY = 0,
	@maxpayout		MONEY = 0,
	@ReportType		TINYINT = 1,
	@max_transid	BIGINT = 0,
	@limitRowCount	INT = 20,
	@ParlayType		VARCHAR(20) = ''
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
		)

		CREATE TABLE #bettype (bettype SMALLINT)

		-- Combo parlay
		DECLARE @ComboType TINYINT = 0 -- 1: mix parlay only, 2: combo parlay only, 3: combined
		
		IF ',' + @ParlayType + ',' LIKE '%,1,%' OR ',' + @ParlayType + ',' LIKE '%,2,%'
		BEGIN
			INSERT INTO #bettype (bettype)
			VALUES (29)

			IF (SELECT COUNT(DISTINCT val) FROM dbo.f_RMS_strSplit(@ParlayType, ',') WHERE val IN (1,2)) = 2
				SELECT @ComboType = 3
			ELSE IF ',' + @ParlayType + ',' LIKE '%,1,%'
				SELECT @ComboType = 1
			ELSE
				SELECT @ComboType = 2
		END

		-- Single match parlay
		IF ',' + @ParlayType + ',' LIKE '%,3,%'
			INSERT INTO #bettype (bettype)
			VALUES (38)

		-- Penalty shootout combo
		IF ',' + @ParlayType + ',' LIKE '%,4,%'
			INSERT INTO #bettype (bettype)
			VALUES (376)

		INSERT INTO #bettrans (transid, bettype, matchid, refno)
		SELECT b.transid, b.bettype, b.matchid, b.refno
		FROM dbo.rmBettrans b WITH (NOLOCK)
			INNER JOIN #bettype bt ON b.bettype = bt.bettype
			INNER JOIN #tmpSelection s ON b.hdp2 = s.selection
			INNER JOIN #tmpSport sp ON b.transid2 = sp.sporttype
		WHERE b.statusID = 0
			AND b.currency <> 20

		DROP TABLE #bettype
		DROP TABLE #tmpSelection
		DROP TABLE #tmpSport

		CREATE CLUSTERED INDEX CIX_bettype ON #bettrans (bettype)

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

		IF EXISTS (SELECT 1 FROM #bettrans WHERE bettype = 29)
		BEGIN
			UPDATE b
			SET b.NumberWon = bm.NumberWon
				,b.market = CASE
								WHEN today = 1 AND early = 0 THEN 1 -- today only
								WHEN today = 0 AND early = 1 THEN 2 -- early only
								ELSE 3 END -- combined
				,b.IsLive = bm.IsLive
				,b.IsBlacklistLeague = bm.IsBlacklistLeague
			FROM #bettrans b
				CROSS APPLY (
					SELECT SUM(NumberWon) AS NumberWon, MAX(today) AS today, MAX(early) AS early, MIN(IsLive) AS IsLive, MAX(IsBlacklistLeague) AS IsBlacklistLeague
					FROM (
						SELECT
							SUM(CASE WHEN bm.StatusID = 112 THEN 1 ELSE 0 END) AS NumberWon
							,MAX(CASE WHEN bm.matchdate = @today THEN 1 ELSE 0 END) AS today
							,MAX(CASE WHEN bm.matchdate = @today THEN 0 ELSE 1 END) AS early
							,MIN(CASE WHEN m.GlobalShowTime < GETDATE() AND m.eventstatus <> 'Completed' THEN 1 ELSE 0 END) AS IsLive
							,MAX(CASE WHEN l.LeagueId IS NOT NULL THEN 1 ELSE 0 END) AS IsBlacklistLeague
						FROM bodb02.dbo.bettransm bm WITH (NOLOCK)
							INNER JOIN bodb02.dbo.match m WITH (NOLOCK) ON bm.matchid = m.matchid
							LEFT JOIN dbo.rmLeague l WITH (NOLOCK) ON m.leagueid = l.LeagueId AND l.GroupId = @BlacklistLeagueGroupId
						WHERE b.refno = bm.refno
							AND bm.winlostdate > @MoveBetsDay

						UNION ALL
						SELECT
							SUM(CASE WHEN bm.StatusID = 112 THEN 1 ELSE 0 END) AS NumberWon
							,MAX(CASE WHEN bm.matchdate = @today THEN 1 ELSE 0 END) AS today
							,MAX(CASE WHEN bm.matchdate = @today THEN 0 ELSE 1 END) AS early
							,MIN(CASE WHEN m.GlobalShowTime < GETDATE() AND m.eventstatus <> 'Completed' THEN 1 ELSE 0 END) AS IsLive
							,MAX(CASE WHEN l.LeagueId IS NOT NULL THEN 1 ELSE 0 END) AS IsBlacklistLeague
						FROM bodb02.dbo.bettransm14 bm WITH (NOLOCK)
							INNER JOIN bodb02.dbo.match14 m WITH (NOLOCK) ON bm.matchid = m.matchid
							LEFT JOIN dbo.rmLeague l WITH (NOLOCK) ON m.leagueid = l.LeagueId AND l.GroupId = @BlacklistLeagueGroupId
						WHERE b.refno = bm.refno
							AND bm.winlostdate BETWEEN @BalanceUpDay AND @MoveBetsDay
					) bm
				) bm
			WHERE b.bettype = 29
		END

		-- filter by market
		BEGIN
			DECLARE @tmpMarket TABLE (market TINYINT)
			INSERT INTO @tmpMarket (market)
			SELECT DISTINCT val FROM dbo.f_RMS_strSplit(@Market, ',')

			IF @@ROWCOUNT < 3
			BEGIN
				DELETE b
				FROM #bettrans b
					LEFT JOIN @tmpMarket m ON b.market = m.market
				WHERE m.market IS NULL
			END
		END
	END

	-- Return data
	BEGIN
		CREATE TABLE #level (level TINYINT)
		INSERT INTO #level (level)
		SELECT DISTINCT val FROM dbo.f_RMS_strSplit(@level, ',')

		SELECT TOP (@limitRowcount)
			rb.custid
			,rb.transdate
			,rb.transid
			,rb.refno
			,rb.username
			,CASE WHEN transid2 NOT IN (-1,-3,1,2,3,4,5,6,7,8,9,11,43,44) THEN -2 ELSE transid2 END AS Sporttype
			,rb.odds2 * rb.TotalBet AS odds
			,rb.statusID
			,rb.stake * rb.actualrate * (1 - rb.tpositiontaking) / rb.TotalBet AS stake
			,(rb.odds2 - 1) * rb.stake * rb.actualrate * (1 - rb.tpositiontaking) AS maxpayout
			,rb.hdp2 AS TotalSelection
			,rb.TotalBet AS TotalBet
			,rb.IP
			,ISNULL(mc.level, 0) AS level
			,0 AS IsBetRadar
			,b.NumberWon
			,rb.bettype
			,b.IsLive
			,b.IsBlacklistLeague
		FROM rmBettrans rb WITH (NOLOCK)
			INNER JOIN #bettrans b ON rb.transid = b.transid
			LEFT JOIN rmCustomer mc WITH (NOLOCK) ON rb.custid = mc.custid
		WHERE
			ISNULL(mc.level, 0) IN (SELECT level FROM #level)
			AND 1 = CASE
					WHEN @reportType = 1 AND (rb.stake * rb.actualrate * (1 - rb.tpositiontaking) / rb.TotalBet) >= @stake THEN 1
					WHEN @reportType = 2 AND (rb.odds2 - 1) * rb.stake * rb.actualrate * (1 - rb.tpositiontaking) >= @maxpayout THEN 1
					ELSE 0 END
			AND 1 = CASE
					WHEN rb.bettype = 29 AND @ComboType IN (1, 2) THEN CASE
						WHEN @ComboType = 1 AND rb.betteam = N'1' THEN 1
						WHEN @ComboType = 2 AND rb.betteam <> N'1' THEN 1
						ELSE 0 END
					ELSE 1 END
		ORDER BY rb.transid DESC
	END
	
	DROP TABLE #bettrans
	DROP TABLE #level
END
GO