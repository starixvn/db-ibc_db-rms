/*<info serverAlias="DBRMS-bodb_RMS" executers="wsv_rms" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[RMS_Monitor_Parlay_MajorBettypeAlert]
	@IsTest BIT = 0,
	@Stake INT = 10

AS

/*
	Created: 20240710@Cherry
	DB: DBRMS-bodb_RMS
	Task: Parlay RMS - Major Bettype has big gap between Home and Away for letstalk

	Revisions:
		- 20240710@Cherry: Initialize SP [RedmineID: #202238]

*/

BEGIN
	SET NOCOUNT ON	

	CREATE TABLE #tmpBettrans(Refno BIGINT, Stake MONEY, hdp2 SMALLMONEY)	
	CREATE TABLE #tmpMatch(MatchID INT, LeagueID INT, HomeID INT, AwayID INT, Sporttype INT, Bettype INT, Maxbet FLOAT)
	CREATE TABLE #tmpBettransm (MatchID INT, Bettype INT, Betteam NVARCHAR(10), Betcheck NVARCHAR(50), Stake MONEY)
	CREATE TABLE #rmAlert (MatchID INT, Bettype INT, Betcheck NVARCHAR(50), AlertType SMALLINT, NumberTime INT)

	CREATE TABLE #tmpData(
		MatchID INT,
		Maxbet FLOAT,
		Bettype INT,
		Betcheck NVARCHAR(50),
		HomeTotalStake MONEY,
		AwayTotalStake MONEY)

	CREATE TABLE #tmpResult(
		MatchID INT,
		Bettype INT,
		Betcheck NVARCHAR(50),
		AlertType SMALLINT,
		NumberTime INT,
		HomeTotalStake MONEY,
		AwayTotalStake MONEY)

	DECLARE @MBBU TABLE (BalanceUpDay SMALLDATETIME, MoveBetsDay SMALLDATETIME)
	INSERT INTO @MBBU (BalanceUpDay, MoveBetsDay)
	EXEC bodb02.dbo.Age_SelBalanceUpDay

	DECLARE @BalanceUpDay SMALLDATETIME, @MoveBetsDay SMALLDATETIME
	SELECT  @BalanceUpDay = BalanceUpDay, @MoveBetsDay = MoveBetsDay FROM @MBBU	

	INSERT INTO #tmpBettrans(Refno, Stake, hdp2)
	SELECT refno, stake * CASE WHEN @IsTest = 1 THEN 1 ELSE actualrate END, hdp2
	FROM dbo.rmBettrans WITH (NOLOCK)
	WHERE bettype = 29
		AND statusID = 0
		AND (@IsTest = 1
			OR (@IsTest = 0 AND currency <> 20))
		AND hdp2 IN (2,3)

	CREATE CLUSTERED INDEX CIX_Refno ON #tmpBettrans(Refno)

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

	CREATE NONCLUSTERED INDEX IX_bettransm ON #tmpBettransm (MatchID, Bettype, Betteam, Betcheck)

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

	CREATE NONCLUSTERED INDEX IX_tmpMatch ON #tmpMatch (MatchID, Bettype)

	INSERT INTO #rmAlert (MatchID, Bettype, Betcheck, AlertType, NumberTime)
	SELECT MatchID, Bettype, Betcheck, AlertType, MAX(NumberTime)
	FROM dbo.rmMajorBettypeAlert WITH(NOLOCK)
	WHERE matchid IN (SELECT matchid FROM #tmpMatch)
	GROUP BY MatchID, Bettype, Betcheck, AlertType

	INSERT INTO #tmpData(
		MatchID,
		Maxbet,
		Bettype,
		Betcheck,
		HomeTotalStake,
		AwayTotalStake)
	SELECT	m.matchID,
			m.maxbet,
			b.Bettype,
			b.Betcheck,
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
	GROUP BY m.matchID,
			m.maxbet,
			b.Bettype,
			b.Betcheck

	INSERT INTO #tmpResult(
		MatchID,
		Bettype,
		Betcheck,
		AlertType,
		NumberTime,
		HomeTotalStake,
		AwayTotalStake)
	SELECT 
		d.MatchID,
		d.Bettype,
		d.Betcheck,
		1 AlertType,
		ISNULL(t.NumberTime + 1,1),		
		HomeTotalStake,
		AwayTotalStake
	FROM #tmpData d		
		LEFT JOIN #rmAlert t ON d.MatchID = t.MatchID AND d.Bettype = t.Bettype AND d.Betcheck = t.Betcheck
	WHERE ISNULL(t.AlertType,1) = 1
		AND (HomeTotalStake - AwayTotalStake) >= ISNULL(t.NumberTime + 1,1) * @Stake * d.Maxbet

	INSERT INTO #tmpResult(
		MatchID,
		Bettype,
		Betcheck,
		AlertType,
		NumberTime,
		HomeTotalStake,
		AwayTotalStake)
	SELECT 
		d.MatchID,
		d.Bettype,
		d.Betcheck,
		2 AlertType,
		ISNULL(t.NumberTime + 1,1),		
		HomeTotalStake,
		AwayTotalStake
	FROM #tmpData d		
		LEFT JOIN #rmAlert t ON d.MatchID = t.MatchID AND d.Bettype = t.Bettype AND d.Betcheck = t.Betcheck
	WHERE ISNULL(t.AlertType,2) = 2
		AND (AwayTotalStake - HomeTotalStake) >= ISNULL(t.NumberTime + 1,1) * @Stake * d.Maxbet

	SELECT m.SportType,
		b.typenamee,
		l.leaguename League,
		h.teamname + ' vs ' + a.teamname [Event],
		HomeTotalStake,
		AwayTotalStake
	FROM #tmpResult d		
		LEFT JOIN #tmpMatch m ON d.MatchID = m.MatchID AND d.Bettype = m.Bettype
		LEFT JOIN #rmAlert t ON d.MatchID = t.MatchID AND d.Bettype = t.Bettype
		LEFT JOIN bodb02.dbo.League l WITH(NOLOCK) ON m.LeagueID = l.leagueid
		LEFT JOIN bodb02.dbo.Team h WITH (NOLOCK) ON m.homeID = h.teamid
		LEFT JOIN bodb02.dbo.Team a WITH (NOLOCK) ON m.awayID = a.teamid
		LEFT JOIN bodb02.dbo.bettype b WITH(NOLOCK) ON d.Bettype = b.typeid

	SELECT MatchID,
		Bettype,
		Betcheck,
		AlertType,
		NumberTime,
		HomeTotalStake,
		AwayTotalStake,
		@IsTest IsTest
	FROM #tmpResult 	
	
	DROP TABLE #tmpBettrans
	DROP TABLE #tmpBettransm
	DROP TABLE #tmpData
	DROP TABLE #tmpMatch
	DROP TABLE #rmAlert
	DROP TABLE #tmpResult

END
GO