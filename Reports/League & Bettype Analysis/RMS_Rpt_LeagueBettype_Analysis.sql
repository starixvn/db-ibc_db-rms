/*<info serverAlias="DBRMS-bodb_RMS" executers="bodbRMSNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[RMS_Rpt_LeagueBettype_Analysis]
	@FromDate		DATE
	,@ToDate		DATE
	,@ParlayType	VARCHAR(100) = '1,2'
	,@LeagueGroups	VARCHAR(MAX) = ''
	,@Leagues		VARCHAR(MAX) = ''
	,@Site			TINYINT = 2
	,@Ratio			FLOAT = 0
	,@ReportBy		TINYINT = 1
	,@SportType		SMALLINT = 1
	,@BetType		INT = 0
	,@HouseWL		MONEY = 0
AS

/*
	Created: 20200619@Percy
	DB: DBRMS-bodb_RMS
	Task: League & Bettype Data Analysis

	Revisions:
		- 20200619@Percy: Initialize SP [RedmineID: #135326]
		- 20220301@Danny: Support basketball Sport type data [RedmineID: #169072]
		- 20220719@Danny: Fix issue Show result of Basketball when selecting Sport is Soccer [RedmineID: #175613]
		- 20231218@Cherry: Enhancement (#197684)

	Param's Explanation:
		. @ParlayType: '1,2'
					. 1 = Mix Parlay
					. 2 = Combo Parlay
		. @Site:
					. 0 = Credit sites
					. 1 = Deposit sites
					. 2 = All sites
		. @Ratio: Won tickets / Total tickets
		. @ReportBy:
					. 1 = League
					. 2 = Bettype
					. 3 = League Details
					. 4 = Bet type Details
*/

BEGIN
	SET NOCOUNT ON

	CREATE TABLE #Leagues (LeagueId INT, GroupName VARCHAR(30))
	CREATE TABLE #Match (MatchID INT, HomeName NVARCHAR(100), AwayName NVARCHAR(100))
	
	-- League Group
	BEGIN
		INSERT INTO #Leagues (LeagueId)
		SELECT val
		FROM dbo.f_RMS_strSplit (@Leagues, ',')

		IF @SportType = 1
		BEGIN

			UPDATE t
			SET t.GroupName	= lg.GroupName
			FROM #Leagues t
				INNER JOIN dbo.rmLeague l WITH (NOLOCK) ON t.LeagueId = l.LeagueId
				INNER JOIN dbo.rmLeagueGroup lg WITH (NOLOCK) ON l.GroupId = lg.GroupId
			WHERE ',' + @LeagueGroups + ',' LIKE '%,' + CONVERT(VARCHAR(5), lg.GroupId)+ ',%'

			DELETE #Leagues WHERE LeagueId <> -1 AND GroupName IS NULL
		
			IF ',' + @LeagueGroups + ',' LIKE '%,-1,%' -- None
				AND ',' + @Leagues + ',' LIKE '%,-1,%' -- None
				INSERT INTO #Leagues (LeagueId, GroupName)
				SELECT s.leagueId, 'None'
				FROM dbo.rmSumByLeague s WITH (NOLOCK)
				INNER JOIN	bodb02.dbo.League l WITH(NOLOCK) ON s.leagueId = l.leagueid
				WHERE s.winlostdate BETWEEN @FromDate AND @ToDate
					AND ',' + @ParlayType + ',' LIKE '%,' + CONVERT(VARCHAR(5), s.ParlayType - 1) + ',%'
					AND (@Site = 2 OR s.IsDeposit = @Site)
					AND NOT EXISTS (SELECT 1 FROM dbo.rmLeague l WITH (NOLOCK) WHERE s.leagueId = l.LeagueId)
					AND l.sporttype = 1
				GROUP BY s.leagueId
		END

		
		IF @SportType = 2
		BEGIN
			UPDATE t
			SET t.GroupName	= lg.GroupName
			FROM #Leagues t
				INNER JOIN bodb02.dbo.League l WITH(NOLOCK) ON t.LeagueId = l.leagueid
				INNER JOIN bodb02.dbo.LeagueGroup lg WITH (NOLOCK) ON l.LeagueGroupID = lg.GroupID
		END

	END

	IF @ReportBy IN (3,4)
	BEGIN
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
	END

	IF @ReportBy = 1 -- view by league
	BEGIN
		SELECT
			l.GroupName
			,l.leagueId
			,SUM(BetCount)			AS TotalTickets
			,SUM(WonCount)			AS WonTickets
			,SUM(DrawCount)			AS DrawTickets
			,SUM(MainWonCount)		AS ParlayWonTickets
			,SUM(MainStake)			AS Stake
			,SUM(MainMemberWinloss)	AS MemberWinloss
			,SUM(MainHouseWinloss)	AS MainHouseWinloss
		FROM dbo.rmSumByLeague s WITH (NOLOCK)
			INNER JOIN #Leagues l ON s.leagueId = l.LeagueId
		WHERE s.winlostdate BETWEEN @FromDate AND @ToDate
			AND ',' + @ParlayType + ',' LIKE '%,' + CONVERT(VARCHAR(5), s.ParlayType - 1) + ',%'
			AND (@Site = 2 OR s.IsDeposit = @Site)
		GROUP BY
			l.GroupName
			,l.leagueId
		HAVING CASE WHEN SUM(BetCount) = 0 THEN 0 ELSE 1.0 * SUM(WonCount)/SUM(BetCount) END >= @Ratio
		ORDER BY TotalTickets DESC
	END
	ELSE IF @ReportBy = 2 -- view by bettype
	BEGIN

		IF @SportType = 1
		BEGIN
			-- all leagues --> leagueid = 0
			IF EXISTS (SELECT 1 FROM #Leagues WHERE GroupName = 'None')
				AND (SELECT COUNT(1) FROM  #Leagues WHERE GroupName <> 'None') = (SELECT COUNT(1) FROM dbo.rmLeague l WITH (NOLOCK))
			BEGIN
				DELETE #Leagues

				INSERT INTO #Leagues (LeagueId)
				VALUES (0)
			END
		END 

		SELECT
			s.Bettype				AS BetTypeId
			,SUM(BetCount)			AS TotalTickets
			,SUM(WonCount)			AS WonTickets
			,SUM(DrawCount)			AS DrawTickets
			,SUM(MainWonCount)		AS ParlayWonTickets
			,SUM(MainStake)			AS Stake
			,SUM(MainMemberWinloss)	AS MemberWinloss
			,SUM(MainHouseWinloss)	AS MainHouseWinloss
		FROM dbo.rmSumByBettype s WITH (NOLOCK)
			INNER JOIN #Leagues l ON s.leagueId = l.LeagueId
		WHERE s.winlostdate BETWEEN @FromDate AND @ToDate
			AND ',' + @ParlayType + ',' LIKE '%,' + CONVERT(VARCHAR(5), s.ParlayType - 1) + ',%'
			AND (@Site = 2 OR s.IsDeposit = @Site)
		GROUP BY
			s.Bettype
		HAVING CASE WHEN SUM(BetCount) = 0 THEN 0 ELSE 1.0 * SUM(WonCount)/SUM(BetCount) END >= @Ratio
		ORDER BY TotalTickets DESC
	END
	ELSE IF @ReportBy = 3 -- view by league detail
	BEGIN		
		SELECT
			m.MatchID MatchId,
			m.HomeName + ' -vs- ' + m.AwayName AS [Event],
			b.typeid BetTypeId,
			b.typenamee AS BetType,
			CASE WHEN s.Bettype IN (1,2,3,5,7,8,12,15) AND s.Betteam IN ('a','h','1','2','x') THEN s.Betteam
				 WHEN s.Bettype IN (20,21,609,610,611,612) AND s.Betteam IN ('a','h') AND @SportType = 2 THEN s.Betteam
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
				  WHEN s.Bettype = 610 AND s.Betteam = 'h' AND @SportType = 2 THEN 'Over'
				  WHEN s.Bettype = 610 AND s.Betteam = 'a' AND @SportType = 2 THEN 'Under'
				  WHEN s.Bettype = 611 AND s.Betteam = 'h' AND @SportType = 2 THEN 'Odd'
				  WHEN s.Bettype = 611 AND s.Betteam = 'a' AND @SportType = 2 THEN 'Even'
				  ELSE '-'
			END AS BetChoice,
			s.TransList,
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
		WHERE s.winlostdate BETWEEN @FromDate AND @ToDate
			AND ',' + @ParlayType + ',' LIKE '%,' + CONVERT(VARCHAR(5), s.ParlayType - 1) + ',%'
			AND (@Site = 2 OR s.IsDeposit = @Site) 
			AND s.leagueId IN (SELECT LeagueId FROM #Leagues)
		GROUP BY
			m.MatchID,
			m.HomeName,
			m.AwayName,
			b.typeid,
			b.typenamee,
			CASE WHEN s.Bettype IN (1,2,3,5,7,8,12,15) AND s.Betteam IN ('a','h','1','2','x') THEN s.Betteam
				 WHEN s.Bettype IN (20,21,609,610,611,612) AND s.Betteam IN ('a','h') AND @SportType = 2 THEN s.Betteam
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
				  WHEN s.Bettype = 610 AND s.Betteam = 'h' AND @SportType = 2 THEN 'Over'
				  WHEN s.Bettype = 610 AND s.Betteam = 'a' AND @SportType = 2 THEN 'Under'
				  WHEN s.Bettype = 611 AND s.Betteam = 'h' AND @SportType = 2 THEN 'Odd'
				  WHEN s.Bettype = 611 AND s.Betteam = 'a' AND @SportType = 2 THEN 'Even'
				  ELSE '-'
			END,
			s.TransList
		HAVING SUM(MainHouseWinloss) <= @HouseWL
		ORDER BY TotalTickets DESC
	END
	ELSE IF @ReportBy = 4 -- view by bettype detail
	BEGIN
		SELECT a.GroupName,
			l.leaguename LeagueName,
			m.MatchID MatchId,
			m.HomeName + ' -vs- ' + m.AwayName AS [Event],
			s.TransList,
			SUM(BetCount)			AS TotalTickets,
			SUM(WonCount)			AS WonTickets,
			SUM(DrawCount)			AS DrawTickets,
			SUM(MainWonCount)		AS ParlayWonTickets,
			SUM(MainStake)			AS Stake,
			SUM(MainMemberWinloss)	AS MemberWinloss,
			SUM(MainHouseWinloss)	AS MainHouseWinloss
		FROM dbo.rmSumByEventBettype s WITH (NOLOCK)
			INNER JOIN #Leagues a ON s.LeagueId = a.LeagueId
			INNER JOIN bodb02.dbo.League l WITH(NOLOCK) ON s.LeagueId = l.leagueid
			INNER JOIN #Match m ON s.MatchId = m.MatchID
		WHERE s.winlostdate BETWEEN @FromDate AND @ToDate
			AND ',' + @ParlayType + ',' LIKE '%,' + CONVERT(VARCHAR(5), s.ParlayType - 1) + ',%'
			AND (@Site = 2 OR s.IsDeposit = @Site) 
			AND s.leagueId IN (SELECT LeagueId FROM #Leagues)
			AND s.Bettype = @BetType
		GROUP BY
			m.MatchID,
			m.HomeName,
			m.AwayName,
			a.GroupName,
			l.leaguename,
			s.TransList
		HAVING SUM(MainHouseWinloss) <= @HouseWL
		ORDER BY TotalTickets DESC
	END

	DROP TABLE #Leagues
	DROP TABLE #Match
END
GO