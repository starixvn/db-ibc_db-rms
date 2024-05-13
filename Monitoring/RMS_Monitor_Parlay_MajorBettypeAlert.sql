/*<info serverAlias="DBRMS-bodb_RMS" executers="wsv_rms" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[RMS_Monitor_Parlay_MajorBettypeAlert]
	@IsTest BIT = 0,
	@Stake INT = 10

AS

/*
	Created: 20240520@Cherry
	DB: DBRMS-bodb_RMS
	Task: Parlay RMS - Major Bettype has big gap between Home and Away for letstalk

	Revisions:
		- 20240520@Cherry: Initialize SP [RedmineID: #202238]

*/

BEGIN
	SET NOCOUNT ON	

	DECLARE @yesterday DATE = DATEADD(DAY,-1, GETDATE())

	CREATE TABLE #tmpBettrans(Refno BIGINT, Stake MONEY, Bettype INT, Betteam NVARCHAR(10))
	CREATE CLUSTERED INDEX cix_#tmpBettrans ON #tmpBettrans(Refno)

	CREATE TABLE #tmpMatch(MatchID INT, HomeID INT, AwayID INT, LeagueID INT, Sporttype INT, Maxbet FLOAT)

	CREATE TABLE #tmpBettype (Bettype SMALLINT, BettypeName NVARCHAR(128), IsMajor BIT)

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
	(	Bettype,
		BettypeName,
		IsMajor
	)
	SELECT	DISTINCT bettype, 
			bt.typenamee, 
			CASE WHEN SportType = 43 THEN CASE WHEN bettype IN (1,2,3,7,8,12,20,21) THEN 1 ELSE 0 END
					WHEN SportType = 2 THEN CASE WHEN bettype IN (1,2,3,7,8,12,20,21,609,610,611,612) THEN 1 ELSE 0 END
					WHEN SportType = 1 THEN CASE WHEN bettype IN (1,2,3,7,8,12,5,15) THEN 1 ELSE 0 END
					ELSE 0 END AS IsMajor  -- 1 Major, 2 Minor
	FROM bodb02.dbo.SportBettypeMatrix m WITH(NOLOCK)
		INNER JOIN bodb02.dbo.bettype bt WITH(NOLOCK) ON m.BetType = bt.typeid
	WHERE SportType IN (1, 2, 43)
	
	INSERT INTO #tmpMatch(MatchID, HomeID, AwayID, LeagueID, Sporttype)
	SELECT  matchid, homeid, awayid, leagueID, sporttype
	FROM	bodb02.dbo.match WITH(NOLOCK)
	WHERE	eventdate >= @yesterday AND sporttype IN (1, 2, 43) AND eventstatus = 'running'	

	UPDATE a
	SET a.Maxbet = CASE WHEN t.Maxbet * 10 < @Stake THEN @Stake ELSE t.Maxbet * 10 END
	FROM #tmpMatch a 
		INNER JOIN (SELECT m.Matchid, MAX(s.maxbet) Maxbet
			FROM #tmpmatch m
				INNER JOIN bodb02.dbo.odds s WITH(NOLOCK) ON m.matchID = s.matchid
			WHERE s.bettype = 1 AND m.Sporttype IN (1, 2)
			GROUP BY m.matchid
			) t ON a.matchID = t.matchID

	UPDATE #tmpMatch
	SET Maxbet = @Stake
	WHERE Sporttype = 43 OR Maxbet IS NULL

	INSERT INTO #tmpBettransm(Refno, Bettype, Betteam, MatchID)
	SELECT  refno, bettype, betteam, matchid
	FROM	bodb02.dbo.bettransm WITH(NOLOCK)
	WHERE	matchid IN (SELECT MatchID FROM #tmpMatch) AND statusID = 0

	INSERT INTO #tmpBettrans
	(
		Refno,
		Stake,
		Bettype,
		Betteam
	)
	SELECT
		b.refno,
		b.stake * CASE WHEN @IsTest = 1 THEN 1 ELSE b.actualrate END,
		b.bettype,
		b.betteam	
	FROM bodb02.dbo.bettrans b WITH (NOLOCK)
	WHERE b.winlostdate >= @yesterday
		AND b.bettype IN (29, 38, 376)
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
			SUM (CASE WHEN sub.betteam IN ('h','o','y','1') AND z.bettype IS NOT NULL AND z.IsMajor = 1 THEN main.stake ELSE 0 END)		HomeTotalStake,
			SUM (CASE WHEN sub.betteam IN ('e','a','u','n','2') AND z.bettype IS NOT NULL AND z.IsMajor = 1  THEN main.stake ELSE 0 END) AwayTotalStake,
			SUM (CASE WHEN sub.betteam NOT IN ('h','o','y','e','a','u','n','1','2')  OR z.bettype IS NULL OR z.IsMajor = 0 THEN main.stake ELSE 0 END) OtherTotalStake
	FROM #tmpBettrans main 
		INNER JOIN	#tmpBettransm sub ON main.refno = sub.refno
		INNER JOIN	#tmpMatch m ON sub.matchID = m.matchID
		INNER JOIN	bodb02.dbo.Sports s WITH(NOLOCK) ON m.sporttype = s.SportType
		LEFT JOIN   #tmpBettype z ON sub.bettype = z.bettype
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