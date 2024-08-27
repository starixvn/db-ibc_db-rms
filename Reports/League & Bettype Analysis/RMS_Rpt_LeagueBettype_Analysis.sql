/*<info serverAlias="DBRMS-bodb_RMS" executers="wsv_rms" isFunction="0" isNested="0"></info>*/
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
AS

/*
	Created: 20200619@Percy
	DB: DBRMS-bodb_RMS
	Task: League & Bettype Data Analysis

	Revisions:
		- 20200619@Percy: Initialize SP [RedmineID: #135326]
		- 20220301@Danny: Support basketball Sport type data [RedmineID: #169072]
		- 20220719@Danny: Fix issue Show result of Basketball when selecting Sport is Soccer [RedmineID: #175613]
		- 20240315@Cherry: Enhancement (#197684)
		- 20240815@Cherry: Get None League Group (#204375)

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
*/

BEGIN
	SET NOCOUNT ON

	CREATE TABLE #Leagues (LeagueId INT, GroupId INT, GroupName VARCHAR(30))
	
	-- League Group
	BEGIN
		INSERT INTO #Leagues (LeagueId)
		SELECT val
		FROM dbo.f_RMS_strSplit (@Leagues, ',')

		IF @SportType = 1
		BEGIN

			UPDATE t
			SET t.GroupName	= lg.GroupName,
				t.GroupId = lg.GroupId
			FROM #Leagues t
				INNER JOIN dbo.rmLeague l WITH (NOLOCK) ON t.LeagueId = l.LeagueId
				INNER JOIN dbo.rmLeagueGroup lg WITH (NOLOCK) ON l.GroupId = lg.GroupId
			WHERE ',' + @LeagueGroups + ',' LIKE '%,' + CONVERT(VARCHAR(5), lg.GroupId)+ ',%'

			UPDATE #Leagues
			SET GroupName = 'None',
				GroupId = -1
			WHERE GroupName IS NULL
			
		END
		
		IF @SportType = 2
		BEGIN
			UPDATE t
			SET t.GroupName	= lg.GroupName,
				t.GroupId = lg.GroupID
			FROM #Leagues t
				INNER JOIN bodb02.dbo.League l WITH(NOLOCK) ON t.LeagueId = l.leagueid
				INNER JOIN bodb02.dbo.LeagueGroup lg WITH (NOLOCK) ON l.LeagueGroupID = lg.GroupID
		END

	END

	IF @ReportBy = 1 -- view by league
	BEGIN
		SELECT
			l.GroupId
			,l.GroupName
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
			l.GroupId
			,l.GroupName
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
			s.Bettype				AS BettypeId
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
END
GO