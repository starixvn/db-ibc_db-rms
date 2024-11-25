/*<info serverAlias="DBRMS-bodb_RMS" executers="wsv_rms" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[RMS_Monitor_Parlay_EventStakeAlert]
	@IsTest BIT = 0,
	@Stake INT = 100000

AS

/*
	Created: 20230520@Cherry
	DB: DBRMS-bodb_RMS
	Task: Parlay RMS - Get Event which big total stake for letstalk

	Revisions:
		- 20230520@Cherry: Initialize SP [RedmineID: #187967]
		- 20240312@Cherry: Change SQL account in metadata (#202012)
		- 20241121@Cherry: Add sport Tennis and Badminton (#208397)
*/

BEGIN
	SET NOCOUNT ON	

	DECLARE @yesterday DATE = DATEADD(DAY,-1, GETDATE())

	CREATE TABLE #tmpBettrans(Refno BIGINT, Stake MONEY, Bettype INT, Betteam NVARCHAR(10), hdp2 SMALLMONEY)
	CREATE CLUSTERED INDEX cix_#tmpBettrans ON #tmpBettrans(Refno)

	CREATE TABLE #tmpMatch(MatchID INT, HomeID INT, AwayID INT, LeagueID INT, Sporttype INT, Maxbet FLOAT)

	CREATE TABLE #tmpBettype (Sporttype INT, Bettype INT, BettypeName NVARCHAR(128), IsMajor BIT)

	CREATE TABLE #tmpBettransm (Refno BIGINT, Bettype INT, Betteam NVARCHAR(10), MatchID INT)
	CREATE CLUSTERED INDEX cix_#tmpBettransm ON #tmpBettransm(Refno)

	CREATE TABLE #tmpData(
		Sport NVARCHAR(50),
		LeagueID INT, 
		MatchID INT,
		HomeID INT,
		AwayID INT,
		Maxbet FLOAT,
		HomeTotalStake MONEY,
		AwayTotalStake MONEY,
		OtherTotalStake MONEY)

	INSERT INTO #tmpBettype 
	(	Sporttype,
		Bettype,
		BettypeName,
		IsMajor
	)
	SELECT	DISTINCT m.SportType,
			bettype, 
			bt.typenamee, 
			CASE WHEN SportType = 43 THEN CASE WHEN bettype IN (1,2,3,7,8,12,20,21) THEN 1 ELSE 0 END
				WHEN SportType = 2 THEN CASE WHEN bettype IN (1,2,3,7,8,12,20,21,609,610,611,612) THEN 1 ELSE 0 END
				WHEN SportType = 1 THEN CASE WHEN bettype IN (1,2,3,7,8,12,5,15) THEN 1 ELSE 0 END
				WHEN SportType = 5 THEN CASE WHEN bettype IN (1,3,20,153,154,155,156) THEN 1 ELSE 0 END
				WHEN SportType = 9 THEN CASE WHEN bettype IN (20,701,704,705,706,707,708,709,710) THEN 1 ELSE 0 END											
				ELSE 0 END AS IsMajor  
	FROM bodb02.dbo.SportBettypeMatrix m WITH(NOLOCK)
		INNER JOIN bodb02.dbo.bettype bt WITH(NOLOCK) ON m.BetType = bt.typeid
	WHERE SportType IN (1, 2, 43, 5, 9)
	
	INSERT INTO #tmpMatch(MatchID, HomeID, AwayID, LeagueID, Sporttype)
	SELECT  matchid, homeid, awayid, leagueID, sporttype
	FROM	bodb02.dbo.match WITH(NOLOCK)
	WHERE	eventdate >= @yesterday AND sporttype IN (1, 2, 43, 5, 9) AND eventstatus = 'running'	

	UPDATE a
	SET a.Maxbet = CASE WHEN t.Maxbet * 10 < @Stake THEN @Stake ELSE t.Maxbet * 10 END
	FROM #tmpMatch a 
		INNER JOIN (SELECT m.Matchid, MAX(s.maxbet) Maxbet
			FROM #tmpmatch m
				INNER JOIN bodb02.dbo.odds s WITH(NOLOCK) ON m.matchID = s.matchid
			WHERE s.bettype = 1 AND m.Sporttype IN (1, 2)
			GROUP BY m.matchid
			) t ON a.matchID = t.matchID

	UPDATE a
	SET a.Maxbet = CASE WHEN t.Maxbet * 10 < @Stake/2 THEN @Stake/2 ELSE t.Maxbet * 10 END
	FROM #tmpMatch a 
		INNER JOIN (SELECT m.Matchid, MAX(s.maxbet) Maxbet
			FROM #tmpmatch m
				INNER JOIN bodb02.dbo.odds s WITH(NOLOCK) ON m.matchID = s.matchid
			WHERE s.bettype = 1 AND m.Sporttype = 5 
			GROUP BY m.matchid
			) t ON a.matchID = t.matchID

	UPDATE a
	SET a.Maxbet = CASE WHEN t.Maxbet * 10 < @Stake/2 THEN @Stake/2 ELSE t.Maxbet * 10 END
	FROM #tmpMatch a 
		INNER JOIN (SELECT m.Matchid, MAX(s.maxbet) Maxbet
			FROM #tmpmatch m
				INNER JOIN bodb02.dbo.odds s WITH(NOLOCK) ON m.matchID = s.matchid
			WHERE s.bettype = 20 AND m.Sporttype = 9
			GROUP BY m.matchid
			) t ON a.matchID = t.matchID

	UPDATE #tmpMatch
	SET Maxbet = @Stake
	WHERE Sporttype = 43 OR Maxbet IS NULL

	INSERT INTO #tmpBettransm(Refno, Bettype, Betteam, MatchID)
	SELECT  refno, bettype, betteam, matchid
	FROM	bodb02.dbo.bettransm WITH(NOLOCK)
	WHERE	matchid IN (SELECT MatchID FROM #tmpMatch) AND statusID = 0

	INSERT INTO #tmpBettransm(Refno, Bettype, Betteam, MatchID)
	SELECT  transid, bettype, betteam, matchid
	FROM	bodb02.dbo.bettrans WITH(NOLOCK)
	WHERE	matchid IN (SELECT MatchID FROM #tmpMatch) AND statusID = 0
			AND bettype = 38
			AND ((@IsTest = 1 AND currency = 20)
              OR (@IsTest = 0 AND currency <> 20)
			  )	
			AND winlostdate >= @yesterday

	INSERT INTO #tmpBettrans
	(
		Refno,
		Stake,
		Bettype,
		Betteam,
		hdp2
	)
	SELECT
		CASE WHEN b.bettype = 29 THEN b.refno ELSE b.transid END,
		b.stake * CASE WHEN @IsTest = 1 THEN 1 ELSE b.actualrate END,
		b.bettype,
		b.betteam,
		b.hdp2
	FROM bodb02.dbo.bettrans b WITH (NOLOCK)
	WHERE b.winlostdate >= @yesterday
		AND b.bettype IN (29,38)
		AND b.statusID = 0
		AND ((@IsTest = 1 AND b.currency = 20)
              OR (@IsTest = 0 AND b.currency <> 20)
			  )	

	INSERT INTO #tmpData(
		Sport,
		LeagueID, 
		MatchID,
		HomeID,
		AwayID,
		Maxbet,
		HomeTotalStake,
		AwayTotalStake,
		OtherTotalStake)
	SELECT	s.SportName,
			m.leagueID, 
			m.matchID,
			m.homeID,
			m.awayID,
			m.maxbet,
			SUM (CASE WHEN sub.betteam IN ('h','o','y','1') AND z.bettype IS NOT NULL AND z.IsMajor = 1 THEN main.stake/main.hdp2 ELSE 0 END)		HomeTotalStake,
			SUM (CASE WHEN sub.betteam IN ('e','a','u','n','2') AND z.bettype IS NOT NULL AND z.IsMajor = 1  THEN main.stake/main.hdp2 ELSE 0 END) AwayTotalStake,
			SUM (CASE WHEN sub.betteam NOT IN ('h','o','y','e','a','u','n','1','2')  OR z.bettype IS NULL OR z.IsMajor = 0 THEN main.stake/main.hdp2 ELSE 0 END) OtherTotalStake
	FROM #tmpBettrans main 
		INNER JOIN	#tmpBettransm sub ON main.refno = sub.refno
		INNER JOIN	#tmpMatch m ON sub.matchID = m.matchID
		INNER JOIN	bodb02.dbo.Sports s WITH(NOLOCK) ON m.sporttype = s.SportType
		LEFT JOIN   #tmpBettype z ON sub.bettype = z.bettype AND m.Sporttype = z.Sporttype
	GROUP BY s.SportName,
			m.leagueID,
			m.matchID,
			m.homeID,
			m.awayID,
			m.maxbet

	SELECT d.Sport Sport,
		l.leaguename League,
		h.teamname + ' vs ' + a.teamname [Event],
		HomeTotalStake,
		AwayTotalStake,
		OtherTotalStake
	FROM #tmpData d		
		LEFT JOIN bodb02.dbo.League l WITH(NOLOCK) ON d.LeagueID = l.leagueid
		LEFT JOIN bodb02.dbo.Team h  WITH (NOLOCK) ON d.homeID = h.teamid
		LEFT JOIN bodb02.dbo.Team a  WITH (NOLOCK) ON d.awayID = a.teamid
	WHERE (d.HomeTotalStake >= d.Maxbet AND d.MatchID*10+1 NOT IN (SELECT TransId FROM dbo.rmLastTicketAlert WITH (NOLOCK) WHERE JobType = 5))
		OR (d.AwayTotalStake >= d.Maxbet AND d.MatchID*10+2 NOT IN (SELECT TransId FROM dbo.rmLastTicketAlert WITH (NOLOCK) WHERE JobType = 5))
		OR (d.OtherTotalStake >= d.Maxbet AND d.MatchID*10+3 NOT IN (SELECT TransId FROM dbo.rmLastTicketAlert WITH (NOLOCK) WHERE JobType = 5)) 

	SELECT MatchID*10+1 TransId,
		HomeTotalStake AlertAmount,
		'Home' ParlayType
	FROM #tmpData
	WHERE HomeTotalStake >= Maxbet AND MatchID*10+1 NOT IN (SELECT TransId FROM dbo.rmLastTicketAlert WITH (NOLOCK) WHERE JobType = 5)
	UNION
	SELECT MatchID*10+2 TransId,
		AwayTotalStake AlertAmount,
		'Away' ParlayType
	FROM #tmpData
	WHERE AwayTotalStake >= Maxbet AND MatchID*10+2 NOT IN (SELECT TransId FROM dbo.rmLastTicketAlert WITH (NOLOCK) WHERE JobType = 5)
	UNION
	SELECT MatchID*10+3 TransId,
		OtherTotalStake AlertAmount,
		'Others' ParlayType
	FROM #tmpData
	WHERE OtherTotalStake >= Maxbet AND MatchID*10+3 NOT IN (SELECT TransId FROM dbo.rmLastTicketAlert WITH (NOLOCK) WHERE JobType = 5)
	 
	DROP TABLE #tmpBettrans
	DROP TABLE #tmpBettransm
	DROP TABLE #tmpBettype
	DROP TABLE #tmpData
	DROP TABLE #tmpMatch

END
GO