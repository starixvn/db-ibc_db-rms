/*<info serverAlias="DBRMS-bodb_RMS" executers="bodbRMSNet" isFunction="0" isNested="0"></info>*/
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
*/

BEGIN
	SET NOCOUNT ON	

	DECLARE @yesterday DATE = DATEADD(DAY,-1, GETDATE())

	CREATE TABLE #tmpbettrans(refno BIGINT, stake MONEY, bettype INT, betteam NVARCHAR(10))
	CREATE CLUSTERED INDEX cix_#tmpbettrans ON #tmpbettrans(refno)

	CREATE TABLE #tmpmatch(matchID INT, homeID INT, awayID INT, leagueID INT, sporttype INT, maxbet FLOAT)

	CREATE TABLE #tmpBettype (bettype SMALLINT, bettypeName NVARCHAR(128), GroupID TINYINT)

	CREATE TABLE #tmpbettransm (refno BIGINT, bettype INT, betteam NVARCHAR(10), matchID INT, odds SMALLMONEY)
	CREATE CLUSTERED INDEX cix_#tmpbettransm ON #tmpbettransm(refno)

	INSERT INTO #tmpBettype 
	(	bettype,
		bettypeName,
		GroupID
	)
	SELECT	DISTINCT bettype, 
			bt.typenamee, 
			CASE WHEN SportType = 43 THEN CASE WHEN bettype IN (1,2,3,7,8,12,20,21) THEN 1 ELSE 2 END
					WHEN SportType = 2 THEN CASE WHEN bettype IN (1,2,3,7,8,12,20,21,609,610,611,612) THEN 1 ELSE 2 END
					WHEN SportType = 1 THEN CASE WHEN bettype IN (1,2,3,7,8,12,5,15) THEN 1 ELSE 2 END
					ELSE 0 END AS GroupID  -- 1 Major, 2 Minor
	FROM bodb02.dbo.SportBettypeMatrix m WITH(NOLOCK)
		INNER JOIN bodb02.dbo.bettype bt WITH(NOLOCK) ON m.BetType = bt.typeid
	WHERE SportType IN (1, 2, 43)
	
	INSERT INTO #tmpmatch(matchID, homeID, awayID, leagueID, sporttype)
	SELECT  matchid, homeid, awayid, leagueID, sporttype
	FROM	bodb02.dbo.match WITH(NOLOCK)
	WHERE	eventdate >= @yesterday AND sporttype IN (1, 2, 43) AND eventstatus = 'running'

	UPDATE #tmpmatch
	SET maxbet = 100000
	WHERE sporttype = 43

	UPDATE a
	SET a.maxbet = CASE WHEN t.maxbet * 10 < 100000 THEN 100000 ELSE t.maxbet * 10 END
	FROM #tmpmatch a 
		INNER JOIN (SELECT m.matchid, MAX(m.maxbet) maxbet
		FROM #tmpmatch m
			INNER JOIN bodb02.dbo.odds s WITH(NOLOCK) ON m.matchID = s.matchid
		WHERE s.bettype = 1
		GROUP BY m.matchid
		) t ON a.matchID = t.matchID

	INSERT INTO #tmpbettransm(refno, bettype, betteam, matchID, odds)
	SELECT  refno, bettype, betteam, matchid, odds
	FROM	bodb02.dbo.bettransm WITH(NOLOCK)
	WHERE	matchid IN (SELECT matchID FROM #tmpmatch) AND statusID = 0

	INSERT INTO #tmpbettrans
	(
		refno,
		stake,
		bettype,
		betteam
	)
	SELECT
		b.refno,
		b.stake * b.actualrate,
		b.bettype,
		b.betteam	
	FROM bodb02.dbo.bettrans b WITH (NOLOCK)
	WHERE b.winlostdate >= @yesterday
		AND b.bettype IN (29, 38, 376)
		AND b.statusID = 0
		 AND ((@IsTest = 1 AND b.currency = 20)
              OR (@IsTest = 0 AND b.currency <> 20)
			  )
		--AND NOT EXISTS (SELECT 1 FROM dbo.rmLastTicketAlert t WITH (NOLOCK) WHERE b.transid = t.transid AND t.JobType = 4)	

	SELECT	m.leagueID, 
			m.matchID,
			m.homeID,
			m.awayID,
			SUM (CASE WHEN sub.betteam IN ('h','o','y','1') AND z.bettype IS NOT NULL AND z.GroupID = 1 THEN main.stake ELSE 0 END)		HomeTotalStake,
			SUM (CASE WHEN sub.betteam IN ('e','a','u','n','2') AND z.bettype IS NOT NULL AND z.GroupID = 1  THEN main.stake ELSE 0 END) AwayTotalStake,
			SUM (CASE WHEN sub.betteam NOT IN ('h','o','y','e','a','u','n','1','2')  OR z.bettype IS NULL OR z.GroupID <> 1 THEN main.stake ELSE 0 END) OtherTotalStake
	FROM #tmpbettrans main 
		INNER JOIN	#tmpbettransm sub ON main.refno = sub.refno
		INNER JOIN	#tmpmatch m ON sub.matchID = m.matchID
		LEFT JOIN   #tmpBettype z ON sub.bettype = z.bettype
	GROUP BY m.leagueID,
			m.matchID,
			m.homeID,
			m.awayID
	
END
GO