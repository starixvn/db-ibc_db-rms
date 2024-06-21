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

	CREATE TABLE #tmpBettrans(Refno BIGINT, Stake MONEY, hdp2 SMALLMONEY)
	CREATE CLUSTERED INDEX cix_#tmpBettrans ON #tmpBettrans(Refno)
	CREATE TABLE #tmpMatch(MatchID INT, HomeID INT, AwayID INT, LeagueID INT, Sporttype INT, Bettype INT, Maxbet FLOAT)
	CREATE TABLE #tmpBettransm (Refno BIGINT, Bettype INT, Betteam NVARCHAR(10), MatchID INT, Stake MONEY)
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

	DECLARE @MBBU TABLE (BalanceUpDay SMALLDATETIME, MoveBetsDay SMALLDATETIME)
	INSERT INTO @MBBU (BalanceUpDay, MoveBetsDay)
	EXEC bodb02.dbo.Age_SelBalanceUpDay

	DECLARE @BalanceUpDay SMALLDATETIME, @MoveBetsDay SMALLDATETIME
	SELECT  @BalanceUpDay = BalanceUpDay, @MoveBetsDay = MoveBetsDay FROM @MBBU

	--INSERT INTO #tmpBettype 
	--(	Bettype,
	--	BettypeName,
	--	IsMajor
	--)
	--SELECT	DISTINCT bettype, 
	--		bt.typenamee, 
	--		CASE WHEN SportType = 43 THEN CASE WHEN bettype IN (1,2,3,7,8,12,20,21) THEN 1 ELSE 0 END
	--				WHEN SportType = 2 THEN CASE WHEN bettype IN (1,2,3,7,8,12,20,21,609,610,611,612) THEN 1 ELSE 0 END
	--				WHEN SportType = 1 THEN CASE WHEN bettype IN (1,2,3,7,8,12,5,15) THEN 1 ELSE 0 END
	--				ELSE 0 END AS IsMajor  -- 1 Major, 2 Minor
	--FROM bodb02.dbo.SportBettypeMatrix m WITH(NOLOCK)
	--	INNER JOIN bodb02.dbo.bettype bt WITH(NOLOCK) ON m.BetType = bt.typeid
	--WHERE SportType IN (1, 2, 43)
	
	

	--UPDATE a
	--SET a.Maxbet = CASE WHEN t.Maxbet * 10 < @Stake THEN @Stake ELSE t.Maxbet * 10 END
	--FROM #tmpMatch a 
	--	INNER JOIN (SELECT m.Matchid, MAX(s.maxbet) Maxbet
	--		FROM #tmpmatch m
	--			INNER JOIN bodb02.dbo.odds s WITH(NOLOCK) ON m.matchID = s.matchid
	--		WHERE s.bettype = 1 AND m.Sporttype IN (1, 2)
	--		GROUP BY m.matchid
	--		) t ON a.matchID = t.matchID

	--UPDATE #tmpMatch
	--SET Maxbet = @Stake
	--WHERE Sporttype = 43 OR Maxbet IS NULL

	INSERT INTO #tmpBettrans(Refno, Stake, hdp2)
	SELECT refno, stake, hdp2
	FROM dbo.rmBettrans WITH (NOLOCK)
	WHERE bettype = 29
		AND statusID = 0
		AND currency <> 20
		AND hdp2 IN (2,3)

	INSERT INTO #tmpBettransm(Refno, Bettype, Betteam, MatchID, Stake)
	SELECT  bm.refno, bm.bettype, bm.betteam, bm.matchid, b.Stake/b.hdp2
	FROM	bodb02.dbo.bettransm bm WITH(NOLOCK)
		INNER JOIN bodb02.dbo.match m WITH (NOLOCK) ON bm.matchid = m.matchid
		INNER JOIN #tmpBettrans b ON bm.refno = b.refno
	WHERE bm.statusID = 0
		AND bm.bettype IN (1,2,3,7,8,12,5,15,20,21,609,610,611,612)
		AND (bm.winlostdate > @MoveBetsDay OR bm.winlostdate IS NULL)
		AND m.sporttype IN (1, 2) 
		AND m.eventstatus = 'running'	
	UNION
	SELECT  bm.refno, bm.bettype, bm.betteam, bm.matchid, b.Stake/b.hdp2
	FROM	bodb02.dbo.bettransm14 bm WITH(NOLOCK)
		INNER JOIN bodb02.dbo.match14 m WITH (NOLOCK) ON bm.matchid = m.matchid
		INNER JOIN #tmpBettrans b ON bm.refno = b.refno
	WHERE bm.statusID = 0
		AND bm.bettype IN (1,2,3,7,8,12,5,15,20,21,609,610,611,612)
		AND (bm.winlostdate > @MoveBetsDay OR bm.winlostdate IS NULL)
		AND m.sporttype IN (1, 2) 
		AND m.eventstatus = 'running'	

	INSERT INTO #tmpMatch(MatchID, HomeID, AwayID, LeagueID, Sporttype, Bettype, Maxbet)
	SELECT  DISTINCT m.matchid, m.homeid, m.awayid, m.leagueID, m.sporttype, s.bettype, s.maxbet
	FROM	bodb02.dbo.match m WITH(NOLOCK)
		INNER JOIN bodb02.dbo.odds s WITH(NOLOCK) ON m.matchID = s.matchid
	WHERE	m.sporttype IN (1, 2) AND m.eventstatus = 'running'	
		AND s.bettype IN (1,2,3,7,8,12,5,15,20,21,609,610,611,612)
		AND m.matchid IN (SELECT matchid FROM #tmpBettransm)
	

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