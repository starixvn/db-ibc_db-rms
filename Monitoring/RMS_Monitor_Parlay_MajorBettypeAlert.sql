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
	CREATE TABLE #tmpMatch(MatchID INT, LeagueID INT, HomeID INT, AwayID INT, Sporttype INT, Bettype INT, Maxbet FLOAT)
	CREATE TABLE #tmpBettransm (MatchID INT, Bettype INT, Betteam NVARCHAR(10), Betcheck NVARCHAR(50), Stake MONEY)

	CREATE TABLE #tmpData(
		Sporttype INT,
		LeagueID INT, 
		MatchID INT,
		HomeID INT,
		AwayID INT,
		Maxbet FLOAT,
		Bettype INT,
		HomeTotalStake MONEY,
		AwayTotalStake MONEY)

	DECLARE @MBBU TABLE (BalanceUpDay SMALLDATETIME, MoveBetsDay SMALLDATETIME)
	INSERT INTO @MBBU (BalanceUpDay, MoveBetsDay)
	EXEC bodb02.dbo.Age_SelBalanceUpDay

	DECLARE @BalanceUpDay SMALLDATETIME, @MoveBetsDay SMALLDATETIME
	SELECT  @BalanceUpDay = BalanceUpDay, @MoveBetsDay = MoveBetsDay FROM @MBBU	

	INSERT INTO #tmpBettrans(Refno, Stake, hdp2)
	SELECT refno, stake, hdp2
	FROM dbo.rmBettrans WITH (NOLOCK)
	WHERE bettype = 29
		AND statusID = 0
		AND (@IsTest = 1
			OR (@IsTest = 0 AND currency <> 20))
		AND hdp2 IN (2,3)

	INSERT INTO #tmpBettransm(MatchID, Bettype, Betteam, Betcheck, Stake)
	SELECT  bm.matchid, bm.bettype, bm.betteam, bm.betcheck, SUM(b.Stake/b.hdp2)
	FROM	bodb02.dbo.bettransm bm WITH(NOLOCK)
		INNER JOIN bodb02.dbo.match m WITH (NOLOCK) ON bm.matchid = m.matchid
		INNER JOIN #tmpBettrans b ON bm.refno = b.refno
	WHERE bm.statusID = 0
		AND bm.bettype IN (1,2,3,7,8,12,5,15,20,21,609,610,611,612)
		AND (bm.winlostdate > @MoveBetsDay OR bm.winlostdate IS NULL)
		AND m.sporttype IN (1, 2) 
		AND m.eventstatus = 'running'	
	GROUP BY bm.matchid, bm.bettype, bm.betteam, bm.betcheck
	UNION
	SELECT  bm.matchid, bm.bettype, bm.betteam, bm.betcheck, SUM(b.Stake/b.hdp2)
	FROM	bodb02.dbo.bettransm14 bm WITH(NOLOCK)
		INNER JOIN bodb02.dbo.match14 m WITH (NOLOCK) ON bm.matchid = m.matchid
		INNER JOIN #tmpBettrans b ON bm.refno = b.refno
	WHERE bm.statusID = 0
		AND bm.bettype IN (1,2,3,7,8,12,5,15,20,21,609,610,611,612)
		AND bm.winlostdate BETWEEN @BalanceUpDay AND @MoveBetsDay
		AND m.sporttype IN (1, 2) 
		AND m.eventstatus = 'running'	
	GROUP BY bm.matchid, bm.bettype, bm.betteam, bm.betcheck

	INSERT INTO #tmpMatch(MatchID, LeagueID, HomeID, AwayID, Sporttype, Bettype, Maxbet)
	SELECT  m.matchid, m.leagueid, m.homeid, m.awayid, m.sporttype, s.bettype, MAX(s.maxbet)
	FROM	bodb02.dbo.match m WITH(NOLOCK)
		INNER JOIN bodb02.dbo.odds s WITH(NOLOCK) ON m.matchID = s.matchid
	WHERE	m.sporttype IN (1, 2) AND m.eventstatus = 'running'	
		AND s.bettype IN (1,2,3,7,8,12,5,15,20,21,609,610,611,612)
		AND m.matchid IN (SELECT matchid FROM #tmpBettransm)
	GROUP BY m.matchid, m.leagueid, m.homeid, m.awayid, m.sporttype, s.bettype
	UNION
	SELECT  m.matchid, m.leagueid, m.homeid, m.awayid, m.sporttype, s.bettype, MAX(s.maxbet)
	FROM	bodb02.dbo.match14 m WITH(NOLOCK)
		INNER JOIN bodb02.dbo.odds s WITH(NOLOCK) ON m.matchID = s.matchid
	WHERE	m.sporttype IN (1, 2) AND m.eventstatus = 'running'	
		AND s.bettype IN (1,2,3,7,8,12,5,15,20,21,609,610,611,612)
		AND m.matchid IN (SELECT matchid FROM #tmpBettransm)
	GROUP BY m.matchid, m.leagueid, m.homeid, m.awayid, m.sporttype, s.bettype

	UPDATE m

	FROM #tmpMatch m
		INNER JOIN dbo.rmMajorBettypeAlert a ON m.matchid = a.matchid AND m.bettype = a.bettype

	INSERT INTO #tmpData(
		Sporttype,
		LeagueID, 
		MatchID,
		HomeID,
		AwayID,
		Maxbet,
		Bettype,
		HomeTotalStake,
		AwayTotalStake)
	SELECT	m.Sporttype,
			m.leagueID, 
			m.matchID,
			m.homeID,
			m.awayID,
			m.maxbet,
			b.Bettype,
			SUM (CASE WHEN b.Bettype IN (1, 2, 3, 7, 8, 12, 20, 21, 609, 612) AND b.Betteam = 'h' THEN b.Stake 
					WHEN b.Bettype IN (5, 15) AND b.Betteam = '1' THEN b.Stake 
					WHEN b.Bettype IN (610, 611) AND b.betteam = 'o' THEN b.Stake 
				ELSE 0 END)	HomeTotalStake,
			SUM (CASE WHEN b.Bettype IN (1, 2, 3, 7, 8, 12, 20, 21, 609, 612) AND b.Betteam = 'a' THEN b.Stake 
					WHEN b.Bettype IN (5, 15) AND b.Betteam = '2' THEN b.Stake 
					WHEN b.Bettype IN (610, 611) AND b.betteam IN ('u', 'e') THEN b.Stake 
				ELSE 0 END) AwayTotalStake
	FROM #tmpBettransm b 
		INNER JOIN #tmpMatch m ON b.matchID = m.matchID AND b.bettype = m.bettype
	GROUP BY m.Sporttype,
			m.leagueID, 
			m.matchID,
			m.homeID,
			m.awayID,
			m.maxbet,
			b.Bettype

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
	DROP TABLE #tmpData
	DROP TABLE #tmpMatch

END
GO