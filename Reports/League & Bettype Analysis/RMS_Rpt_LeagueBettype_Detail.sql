/*<info serverAlias="DBRMS-bodb_RMS" executers="wsv_rms" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[RMS_Rpt_LeagueBettype_Detail]
	@FromDate		DATE
	,@ToDate		DATE
	,@ParlayType	VARCHAR(100) = '1,2,3'
	,@LeagueGroups	VARCHAR(MAX) = ''
	,@Leagues		VARCHAR(MAX) = ''
	,@Match			INT = 0
	,@Site			TINYINT = 2
	,@SportType		SMALLINT = 1
	,@BetTeam		NVARCHAR(50) = '' 
	,@BetType		INT = 0
	,@ReportBy		TINYINT = 1
	,@HouseWL		MONEY = 0

AS

/*
	Created: 20240315@Cherry
	DB: DBRMS-bodb_RMS
	Task: League & Bettype Data Analysis

	Revisions:
		- 20240315@Cherry: Initialize SP [RedmineID: #197684]
		- 20241030@Cherry: Add Single Match Parlay (#209293)

	Param's Explanation:
		. @ParlayType: '1,2'
					. 1 = Mix Parlay
					. 2 = Combo Parlay
					. 3 = Single Match Parlay
		. @Site:
					. 0 = Credit sites
					. 1 = Deposit sites
					. 2 = All sites
		. @ReportBy:
					. 1 = League details
					. 2 = Bettype details
					. 3 = Ticket details

*/

BEGIN
	SET NOCOUNT ON

	CREATE TABLE #Leagues (LeagueId INT, GroupName VARCHAR(200), LeagueName NVARCHAR(500))
	CREATE TABLE #Match (MatchID INT, HomeName NVARCHAR(100), AwayName NVARCHAR(100))
	
	-- League Group
	BEGIN
		INSERT INTO #Leagues (LeagueId)
		SELECT val
		FROM dbo.f_RMS_strSplit (@Leagues, ',')

		IF @SportType = 1
		BEGIN

			UPDATE t
			SET t.GroupName	= lg.GroupName,
				t.LeagueName = a.leaguename
			FROM #Leagues t
				INNER JOIN dbo.rmLeague l WITH (NOLOCK) ON t.LeagueId = l.LeagueId
				INNER JOIN dbo.rmLeagueGroup lg WITH (NOLOCK) ON l.GroupId = lg.GroupId
				INNER JOIN	bodb02.dbo.League a WITH(NOLOCK) ON t.leagueId = a.leagueid
			WHERE ',' + @LeagueGroups + ',' LIKE '%,' + CONVERT(VARCHAR(5), lg.GroupId)+ ',%'

			UPDATE t
			SET t.GroupName	= 'None',
				t.LeagueName = l.leaguename
			FROM #Leagues t
				INNER JOIN bodb02.dbo.League l WITH(NOLOCK) ON t.LeagueId = l.leagueid
			WHERE t.LeagueId NOT IN (SELECT LeagueId FROM dbo.rmLeague WITH(NOLOCK))
		
			IF ',' + @LeagueGroups + ',' LIKE '%,-1,%' -- None
				AND ',' + @Leagues + ',' LIKE '%,-1,%' -- None
				INSERT INTO #Leagues (LeagueId, GroupName, LeagueName)
				SELECT s.leagueId, 'None', l.leaguename
				FROM dbo.rmSumByLeague s WITH (NOLOCK)
					INNER JOIN	bodb02.dbo.League l WITH(NOLOCK) ON s.leagueId = l.leagueid
				WHERE s.winlostdate BETWEEN @FromDate AND @ToDate
					AND ',' + @ParlayType + ',' LIKE '%,' + CONVERT(VARCHAR(5), s.ParlayType - 1) + ',%'
					AND (@Site = 2 OR s.IsDeposit = @Site)
					AND NOT EXISTS (SELECT 1 FROM dbo.rmLeague l WITH (NOLOCK) WHERE s.leagueId = l.LeagueId)
					AND l.sporttype = 1
				GROUP BY s.leagueId, l.leaguename
		END

		
		IF @SportType = 2
		BEGIN
			UPDATE t
			SET t.GroupName	= lg.GroupName,
				t.LeagueName = l.leaguename
			FROM #Leagues t
				INNER JOIN bodb02.dbo.League l WITH(NOLOCK) ON t.LeagueId = l.leagueid
				INNER JOIN bodb02.dbo.LeagueGroup lg WITH (NOLOCK) ON l.LeagueGroupID = lg.GroupID
		END

	END
	
	INSERT INTO #Match(MatchID)
	SELECT DISTINCT MatchId
	FROM dbo.rmSumByEventBettype s WITH (NOLOCK)
	WHERE s.winlostdate BETWEEN @FromDate AND @ToDate
		AND ',' + @ParlayType + ',' LIKE '%,' + CONVERT(VARCHAR(5), s.ParlayType - 1) + ',%'
		AND (@Site = 2 OR s.IsDeposit = @Site)
		AND s.leagueId IN (SELECT LeagueId FROM #Leagues)

	UPDATE t
	SET t.HomeName = h.teamname,
		t.AwayName = a.teamname
	FROM #Match t
		INNER JOIN bodb02.dbo.match m WITH (NOLOCK) ON t.matchid = m.matchid
		INNER JOIN bodb02.dbo.Team h WITH (NOLOCK) ON m.homeid = h.teamid
		INNER JOIN bodb02.dbo.Team a WITH (NOLOCK) ON m.awayid = a.teamid

	UPDATE t
	SET t.HomeName = h.teamname,
		t.AwayName = a.teamname
	FROM #Match t
		INNER JOIN bodb02.dbo.match14 m WITH (NOLOCK) ON t.matchid = m.matchid
		INNER JOIN bodb02.dbo.Team h WITH (NOLOCK) ON m.homeid = h.teamid
		INNER JOIN bodb02.dbo.Team a WITH (NOLOCK) ON m.awayid = a.teamid
	WHERE t.HomeName IS NULL

	UPDATE t
	SET t.HomeName = h.teamname,
		t.AwayName = a.teamname
	FROM #Match t
		INNER JOIN DBARC.bodb_archive.dbo.match_bk m WITH (NOLOCK) ON t.matchid = m.matchid
		INNER JOIN bodb02.dbo.Team h WITH (NOLOCK) ON m.homeid = h.teamid
		INNER JOIN bodb02.dbo.Team a WITH (NOLOCK) ON m.awayid = a.teamid
	WHERE t.HomeName IS NULL
	
	IF @ReportBy = 1 -- view by league detail
	BEGIN		
		SELECT GroupName,
			LeagueName,
			MatchId,
			[Event],
			BetTypeId,
			BetType,
			BetTeam,
			BetChoice,
			SUM(TotalTickets)		AS TotalTickets,
			SUM(WonTickets)			AS WonTickets,
			SUM(DrawTickets)		AS DrawTickets,
			SUM(ParlayWonTickets)	AS ParlayWonTickets,
			SUM(Stake)				AS Stake,
			SUM(MemberWinloss)		AS MemberWinloss,
			SUM(MainHouseWinloss)	AS MainHouseWinloss
		FROM (
		SELECT
			l.GroupName,
			l.LeagueName,
			m.MatchID MatchId,
			m.HomeName + ' -vs- ' + m.AwayName AS [Event],
			b.typeid BetTypeId,
			b.typenamee AS BetType,
			CASE WHEN s.Bettype IN (1,2,3,5,7,8,12,15) AND s.Betteam IN ('a','h','1','2','x') THEN s.Betteam
				 WHEN s.Bettype IN (20,21,609,610,611,612) AND s.Betteam IN ('a','h','o','u','e') AND @SportType = 2 THEN s.Betteam				
				 ELSE '-'
			END BetTeam,
			CASE WHEN s.Bettype IN (1, 7) AND s.Betteam = 'h' THEN m.HomeName
				  WHEN s.Bettype IN (1, 7) AND s.Betteam = 'a' THEN m.AwayName
				  WHEN s.Bettype IN (2, 12) AND s.Betteam = 'h' THEN 'Odd'
				  WHEN s.Bettype IN (2, 12) AND s.Betteam = 'a' THEN 'Even'
				  WHEN s.Bettype IN (3, 8) AND s.Betteam = 'h' THEN 'Over'
				  WHEN s.Bettype IN (3, 8) AND s.Betteam = 'a' THEN 'Under'
				  WHEN s.Bettype IN (5, 15) AND s.Betteam = '1' THEN m.HomeName
				  WHEN s.Bettype IN (5, 15) AND s.Betteam = '2' THEN m.AwayName
				  WHEN s.Bettype IN (5, 15) AND s.Betteam = 'x' THEN 'Draw'
				  WHEN s.Bettype IN (20, 21, 609, 612) AND s.Betteam = 'h' AND @SportType = 2 THEN m.HomeName
				  WHEN s.Bettype IN (20, 21, 609, 612) AND s.Betteam = 'a' AND @SportType = 2 THEN m.AwayName
				  WHEN s.Bettype = 610 AND s.Betteam = 'o' AND @SportType = 2 THEN 'Over'
				  WHEN s.Bettype = 610 AND s.Betteam = 'u' AND @SportType = 2 THEN 'Under'
				  WHEN s.Bettype = 611 AND s.Betteam = 'o' AND @SportType = 2 THEN 'Odd'
				  WHEN s.Bettype = 611 AND s.Betteam = 'e' AND @SportType = 2 THEN 'Even'
				  ELSE '-'
			END AS BetChoice,
			SUM(BetCount)			AS TotalTickets,
			SUM(WonCount)			AS WonTickets,
			SUM(DrawCount)			AS DrawTickets,
			SUM(MainWonCount)		AS ParlayWonTickets,
			SUM(MainStake)			AS Stake,
			SUM(MainMemberWinloss)	AS MemberWinloss,
			SUM(MainHouseWinloss)	AS MainHouseWinloss
		FROM dbo.rmSumByEventBettype s WITH (NOLOCK)
			INNER JOIN #Match m ON s.MatchId = m.MatchID
			INNER JOIN bodb02.dbo.bettype b WITH(NOLOCK) ON s.Bettype = b.typeid
			INNER JOIN #Leagues l ON s.leagueid = l.leagueid			
		WHERE s.winlostdate BETWEEN @FromDate AND @ToDate
			AND ',' + @ParlayType + ',' LIKE '%,' + CONVERT(VARCHAR(5), s.ParlayType - 1) + ',%'
			AND (@Site = 2 OR s.IsDeposit = @Site) 	
			AND s.bettype <> 38
		GROUP BY
			l.GroupName,
			l.LeagueName,
			m.MatchID,
			m.HomeName,
			m.AwayName,
			b.typeid,
			b.typenamee,
			CASE WHEN s.Bettype IN (1,2,3,5,7,8,12,15) AND s.Betteam IN ('a','h','1','2','x') THEN s.Betteam
				 WHEN s.Bettype IN (20,21,609,610,611,612) AND s.Betteam IN ('a','h','o','u','e') AND @SportType = 2 THEN s.Betteam
				 ELSE '-'
			END,
			CASE WHEN s.Bettype IN (1, 7) AND s.Betteam = 'h' THEN m.HomeName
				  WHEN s.Bettype IN (1, 7) AND s.Betteam = 'a' THEN m.AwayName
				  WHEN s.Bettype IN (2, 12) AND s.Betteam = 'h' THEN 'Odd'
				  WHEN s.Bettype IN (2, 12) AND s.Betteam = 'a' THEN 'Even'
				  WHEN s.Bettype IN (3, 8) AND s.Betteam = 'h' THEN 'Over'
				  WHEN s.Bettype IN (3, 8) AND s.Betteam = 'a' THEN 'Under'
				  WHEN s.Bettype IN (5, 15) AND s.Betteam = '1' THEN m.HomeName
				  WHEN s.Bettype IN (5, 15) AND s.Betteam = '2' THEN m.AwayName
				  WHEN s.Bettype IN (5, 15) AND s.Betteam = 'x' THEN 'Draw'
				  WHEN s.Bettype IN (20, 21, 609, 612) AND s.Betteam = 'h' AND @SportType = 2 THEN m.HomeName
				  WHEN s.Bettype IN (20, 21, 609, 612) AND s.Betteam = 'a' AND @SportType = 2 THEN m.AwayName
				  WHEN s.Bettype = 610 AND s.Betteam = 'o' AND @SportType = 2 THEN 'Over'
				  WHEN s.Bettype = 610 AND s.Betteam = 'u' AND @SportType = 2 THEN 'Under'
				  WHEN s.Bettype = 611 AND s.Betteam = 'o' AND @SportType = 2 THEN 'Odd'
				  WHEN s.Bettype = 611 AND s.Betteam = 'e' AND @SportType = 2 THEN 'Even'
				  ELSE '-'
			END
		HAVING SUM(MainHouseWinloss) <= @HouseWL
		UNION ALL
		SELECT
			l.GroupName,
			l.LeagueName,
			m.MatchID MatchId,
			m.HomeName + ' -vs- ' + m.AwayName AS [Event],
			b.typeid BetTypeId,
			b.typenamee AS BetType,
			s.Betteam Betteam,
			t.SelectionName BetChoice,
			SUM(BetCount)			AS TotalTickets,
			SUM(WonCount)			AS WonTickets,
			SUM(DrawCount)			AS DrawTickets,
			SUM(MainWonCount)		AS ParlayWonTickets,
			SUM(MainStake)			AS Stake,
			SUM(MainMemberWinloss)	AS MemberWinloss,
			SUM(MainHouseWinloss)	AS MainHouseWinloss
		FROM dbo.rmSumByEventBettype s WITH (NOLOCK)
			INNER JOIN #Match m ON s.MatchId = m.MatchID
			INNER JOIN bodb02.dbo.bettype b WITH(NOLOCK) ON s.Bettype = b.typeid
			INNER JOIN #Leagues l ON s.leagueid = l.leagueid
			INNER JOIN bodb02.dbo.SMP_Selection t WITH(NOLOCK) ON CAST(s.betteam AS INT) = t.SelectionType 
		WHERE s.winlostdate BETWEEN @FromDate AND @ToDate
			AND ',' + @ParlayType + ',' LIKE '%,' + CONVERT(VARCHAR(5), s.ParlayType - 1) + ',%'
			AND (@Site = 2 OR s.IsDeposit = @Site) 
			AND s.bettype = 38
		GROUP BY
			l.GroupName,
			l.LeagueName,
			m.MatchID,
			m.HomeName,
			m.AwayName,
			b.typeid,
			b.typenamee,
			s.Betteam,
			t.SelectionName
		HAVING SUM(MainHouseWinloss) <= @HouseWL	
		) t
		GROUP BY GroupName,
			LeagueName,
			MatchId,
			[Event],
			BetTypeId,
			BetType,
			BetTeam,
			BetChoice
		ORDER BY MainHouseWinloss DESC
	END
	
	IF @ReportBy = 2 -- view by bettype detail
	BEGIN
		SELECT l.GroupName,
			l.LeagueName,
			m.MatchID MatchId,
			m.HomeName + ' -vs- ' + m.AwayName AS [Event],
			SUM(BetCount)			AS TotalTickets,
			SUM(WonCount)			AS WonTickets,
			SUM(DrawCount)			AS DrawTickets,
			SUM(MainWonCount)		AS ParlayWonTickets,
			SUM(MainStake)			AS Stake,
			SUM(MainMemberWinloss)	AS MemberWinloss,
			SUM(MainHouseWinloss)	AS MainHouseWinloss
		FROM dbo.rmSumByEventBettype s WITH (NOLOCK)
			INNER JOIN #Leagues l ON s.LeagueId = l.LeagueId
			INNER JOIN #Match m ON s.MatchId = m.MatchID
		WHERE s.winlostdate BETWEEN @FromDate AND @ToDate
			AND ',' + @ParlayType + ',' LIKE '%,' + CONVERT(VARCHAR(5), s.ParlayType - 1) + ',%'
			AND (@Site = 2 OR s.IsDeposit = @Site) 
			AND (@BetType = 0 OR s.Bettype = @BetType)
			AND (s.bettype <> 38 OR
				(s.bettype = 38 AND s.Betteam = '0'))
		GROUP BY
			m.MatchID,
			m.HomeName,
			m.AwayName,
			l.GroupName,
			l.leaguename
		HAVING SUM(MainHouseWinloss) <= @HouseWL			
		ORDER BY MainHouseWinloss DESC
	END

	DECLARE @MBU TABLE (BalanceUpDay SMALLDATETIME, MoveBetsDay SMALLDATETIME)
	INSERT INTO @MBU (BalanceUpDay, MoveBetsDay)
	EXEC bodb02.dbo.Age_SelBalanceUpDay

	DECLARE @MoveBetsDay DATETIME
	SELECT @MoveBetsDay = MoveBetsDay FROM @MBU		
	
	CREATE TABLE #tmpTransList (TransID BIGINT)
	
	CREATE TABLE #tmpBettrans
	(
		TransDate			DATETIME,
		TransId				BIGINT,
		UserName			NVARCHAR(50),
		BetType				SMALLINT,
		Odds				SMALLMONEY,
		StakeAfterPT		MONEY,
		WinningAmount		MONEY,
		NetWinAfterPT		MONEY,
		TotalBet			INT,
		TotalSelection		SMALLMONEY,
		SportType			SMALLINT,
		IP					VARCHAR(45),
		CurrencyName		NVARCHAR(50),
		CustomerClass		SMALLINT
	)		
	
	IF @ReportBy = 3
	BEGIN
		INSERT INTO #tmpTransList (TransID)
		SELECT DISTINCT a.val
		FROM dbo.rmSumByEventBettype s WITH (NOLOCK)
			CROSS APPLY OPENJSON (CAST(DECOMPRESS(s.TransList) AS NVARCHAR(MAX))) WITH (tl VARCHAR(MAX)) 
			CROSS APPLY bodb02.dbo.strSplit(tl,',') a
		WHERE s.winlostdate BETWEEN @FromDate AND @ToDate
			AND ',' + @ParlayType + ',' LIKE '%,' + CONVERT(VARCHAR(5), s.ParlayType - 1) + ',%'
			AND (@Site = 2 OR s.IsDeposit = @Site) 
			AND s.Bettype = @BetType
			AND s.matchid = @Match
			AND (@BetTeam = ''
				OR (@BetTeam = '-' AND s.Betteam NOT IN ('a','h','1','2','x','o','u','e'))
				OR s.Betteam = @BetTeam)		
		
	INSERT INTO #tmpBettrans
	(
		transdate,
		transid,
		username,
		BetType,
		odds,
		StakeAfterPT,
		WinningAmount,
		NetWinAfterPT,
		TotalBet,
		TotalSelection,
		SportType,
		IP,
		currencyName,
		CustomerClass		
	)			
	SELECT
		b.transdate
		,b.transid
		,b.Username
		,b.bettype
		,(b.winlost - b.actual_stake) / b.stake AS odds
		,b.stake * (1 - b.tpositiontaking - CONVERT(DECIMAL(9, 8), ISNULL(b.epositiontaking, 0))) * b.actualrate AS StakeAfterPT
		,(b.winlost - b.actual_stake) * b.actualrate AS WinningAmount
		,((winlost - actual_stake) * (1 - b.tpositiontaking - CONVERT(DECIMAL(9, 8), ISNULL(b.epositiontaking, 0))) + scomm - CASE WHEN tpositiontaking = 1 THEN 0 ELSE scomm * CONVERT(DECIMAL(9, 8), ISNULL(b.epositiontaking, 0)) / (1 - tpositiontaking) END) * actualrate AS NetWinAfterPT
		,b.TotalBet
		,b.hdp2 AS TotalSelection
		,b.transid2 AS SportType
		,b.IP
		,b.CurrencyName
		,ci.CustomerClass
	FROM dbo.rmBettrans b WITH (NOLOCK)
		INNER JOIN bodb02.dbo.CustInfo ci WITH(NOLOCK) ON b.custid = ci.custid
	WHERE b.transid IN (SELECT TransID FROM #tmpTransList)

	INSERT INTO #tmpBettrans
	(
		transdate,
		transid,
		username,
		BetType,
		odds,
		StakeAfterPT,
		WinningAmount,
		NetWinAfterPT,
		TotalBet,
		TotalSelection,
		SportType,
		IP,
		currencyName,
		CustomerClass		
	)			
	SELECT
		b.transdate
		,b.transid
		,b.Username
		,b.bettype
		,(b.winlost - b.actual_stake) / b.stake AS odds
		,b.stake * (1 - b.tpositiontaking - CONVERT(DECIMAL(9, 8), ISNULL(b.epositiontaking, 0))) * b.actualrate AS StakeAfterPT
		,(b.winlost - b.actual_stake) * b.actualrate AS WinningAmount
		,((winlost - actual_stake) * (1 - b.tpositiontaking - CONVERT(DECIMAL(9, 8), ISNULL(b.epositiontaking, 0))) + scomm - CASE WHEN tpositiontaking = 1 THEN 0 ELSE scomm * CONVERT(DECIMAL(9, 8), ISNULL(b.epositiontaking, 0)) / (1 - tpositiontaking) END) * actualrate AS NetWinAfterPT
		,b.TotalBet
		,b.hdp2 AS TotalSelection
		,b.transid2 AS SportType
		,b.IP
		,b.CurrencyName
		,ci.CustomerClass
	FROM dbo.rmBettrans_Old b WITH (NOLOCK)
		INNER JOIN bodb02.dbo.CustInfo ci WITH(NOLOCK) ON b.custid = ci.custid
	WHERE b.transid IN (SELECT TransID FROM #tmpTransList)
		AND b.transid NOT IN (SELECT TransID FROM #tmpBettrans)

	SELECT
		TransDate,
		TransId,
		UserName,
		CustomerClass,
		CurrencyName,
		Odds,
		StakeAfterPT,
		WinningAmount,
		NetWinAfterPT,
		TotalBet,
		TotalSelection,
		SportType,
		IP,
		CASE WHEN BetType = 38 THEN 1 ELSE 0 END IsSMP
	FROM #tmpBettrans
	END

	DROP TABLE #tmpBettrans
	DROP TABLE #tmpTransList

END
GO