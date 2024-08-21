/*<info serverAlias="DBRMS-bodb_RMS" executers="wsv_rms" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[RMS_Monitor_SingleMatchBigOddsAlert]
	@IsTest BIT = 0
AS

/*
	Created: 20240815@Cherry
	DB: DBRMS-bodb_RMS
	Task: Parlay RMS - Get single match parlay tickets which big odds for letstalk

	Revisions:
		- 20240815@Cherry: Initialize SP [RedmineID: #209293]

*/

BEGIN
	SET NOCOUNT ON

	DECLARE @LastTransDate DATETIME, @TransDate DATETIME
	SELECT	@LastTransDate = dbo.f_RMS_rmSettings('SingleMatchBigOddsAlert_LastTransDate')
	SELECT  @TransDate = MAX(TransDate) FROM dbo.rmBettrans WITH (NOLOCK)

	IF @LastTransDate IS NULL
		SET @LastTransDate = CONVERT(DATE, GETDATE()) -- from begin today
	ELSE
		SET @LastTransDate = DATEADD(HOUR, -1, @LastTransDate)

	CREATE TABLE #Result
	(		
		TransId BIGINT,
		SportName NVARCHAR(50),
		LeagueID INT,
		MatchID INT,
		HomeID INT,
		AwayID INT,
		Score VARCHAR(100),
		ParlayType VARCHAR(50),
		stake MONEY,
		WinningAmount MONEY,
		CompanyLoseAmount MONEY,
		Selection SMALLMONEY,
		odds SMALLMONEY,
		TotalBets INT
	)

	CREATE TABLE #tmpBettrans 
		(transid BIGINT, 
		matchid INT,
		hdp2 MONEY,
		odds2 MONEY,
		liveindicator BIT,
		livehomescore SMALLINT,
		liveawayscore SMALLINT,
		Stake MONEY,
		WinningAmount MONEY,
		CompanyLoseAmount MONEY,
		TotalBets INT)

	CREATE TABLE #tmpMatch
		(matchid INT, 
		homeid INT, 
		awayid INT, 
		sporttype INT, 
		leagueid INT)

	INSERT INTO #tmpBettrans 
		(transid, 
		matchid,
		hdp2,
		odds2,
		liveindicator,
		livehomescore,		
		Stake,
		WinningAmount,
		CompanyLoseAmount,
		TotalBets)
	SELECT transid,
		b.matchid,
		b.hdp2,
		b.odds2,
		b.liveindicator,
		CASE WHEN b.liveindicator = 1 THEN b.livehomescore ELSE NULL END livehomescore,		
		stake * CASE WHEN @IsTest = 1 THEN 1 ELSE actualrate END Stake,
		(b.odds2 - 1) * b.stake * CASE WHEN @IsTest = 1 THEN 1 ELSE b.actualrate END AS WinningAmount,
		(b.odds2 - 1) * b.stake * CASE WHEN @IsTest = 1 THEN 1 ELSE b.actualrate END * (1 - b.tpositiontaking) AS CompanyLoseAmount,
		b.TotalBet
	FROM dbo.rmBettrans b WITH (NOLOCK)
	WHERE TransDate > @LastTransDate
		AND bettype = 38
		AND statusID = 0
		AND ((@IsTest = 0 AND currency <> 20) 
			OR (@IsTest = 1 AND currency = 20)
			)
		AND ((hdp2 IN (2,3) AND odds2 > 40)
			OR (hdp2 IN (4,5) AND odds2 > 80)
			OR (hdp2 >= 6 AND odds2 > 100)
			)
		AND NOT EXISTS (SELECT 1 FROM dbo.rmLastTicketAlert t WITH (NOLOCK) WHERE b.transid = t.transid AND t.JobType = 6)

	UPDATE t
	SET t.liveawayscore = b.liveawayscore
	FROM #tmpBettrans t
		INNER JOIN bodb02.dbo.bettrans b WITH(NOLOCK) ON t.transid = b.transid
	WHERE b.liveindicator = 1

	UPDATE t
	SET t.liveawayscore = b.liveawayscore
	FROM #tmpBettrans t
		INNER JOIN bodb02.dbo.bettrans14 b WITH(NOLOCK) ON t.transid = b.transid
	WHERE t.liveawayscore IS NULL
		AND b.liveindicator = 1

	INSERT INTO #tmpMatch 
		(matchid, 
		homeid, 
		awayid, 
		sporttype, 
		leagueid)
	SELECT 
		m.matchid,
		m.homeid,
		m.awayid,
		m.sporttype,
		m.leagueid
	FROM bodb02.dbo.match m WITH (NOLOCK)		
	WHERE m.matchid IN (SELECT matchid FROM #tmpBettrans)
	
	INSERT INTO #tmpMatch 
		(matchid, 
		homeid, 
		awayid, 
		sporttype, 
		leagueid)
	SELECT 
		m.matchid,
		m.homeid,
		m.awayid,
		m.sporttype,
		m.leagueid
	FROM bodb02.dbo.match14 m WITH (NOLOCK) 
	WHERE m.matchid IN (SELECT matchid FROM #tmpBettrans)
		AND m.matchid NOT IN (SELECT matchid FROM #tmpMatch)

	INSERT INTO #Result
	(
		TransId,
		SportName,
		LeagueID,
		MatchID,
		HomeID,
		AwayID,
		Score,
		ParlayType,
		stake,
		WinningAmount,
		CompanyLoseAmount,
		Selection,
		odds,
		TotalBets 
	)	
	SELECT
		b.TransId,
		s.SportName,
		m.leagueid, 
		m.matchid,
		m.homeid,
		m.awayid,
		CASE WHEN b.liveindicator = 1 THEN
				CASE WHEN m.sporttype = 1 THEN '[' + CAST(b.livehomescore AS VARCHAR(10)) + '-' + CAST(b.liveawayscore AS VARCHAR(10)) + ']'
					ELSE '[Live]'
				END
			ELSE NULL
		END AS [Score],
		'Single Match Parlay' AS ParlayType,
		b.stake,
		b.WinningAmount,
		b.CompanyLoseAmount,
		b.hdp2,
		b.odds2,
		b.TotalBets
	FROM #tmpBettrans b		
		INNER JOIN #tmpMatch m ON m.matchid = b.matchid
		INNER JOIN bodb02.dbo.Sports s WITH(NOLOCK) ON m.sporttype = s.SportType

	SELECT 
		d.SportName Sport,
		l.leaguename League,
		h.teamname + ' vs ' + a.teamname [Event],
		d.TransId BetId,
		d.Score,		
		d.Selection,
		d.odds,
		d.ParlayType,
		d.stake Stake,
		d.WinningAmount,
		COMPRESS((SELECT CAST(TransId AS VARCHAR) AS 'tl',
					ParlayType AS 'sp',
					CAST(Selection AS VARCHAR) AS 'sl',
					Odds AS 'od',
					TotalBets AS 'tb',
					stake AS 'ms',
					WinningAmount AS 'pw',
					CompanyLoseAmount AS 'pl'
				FROM #result t
				WHERE t.TransId = d.TransId 
					FOR JSON PATH
					,INCLUDE_NULL_VALUES
				)) TransInfo
	FROM #Result d
		INNER JOIN bodb02.dbo.League l WITH(NOLOCK) ON d.LeagueID = l.leagueid
		INNER JOIN bodb02.dbo.Team h WITH(NOLOCK) ON d.HomeID = h.teamid
		INNER JOIN bodb02.dbo.Team a WITH(NOLOCK) ON d.AwayID = a.teamid

	SELECT CONVERT(VARCHAR(200), @TransDate, 121) AS TransDate

	DROP TABLE #Result
	DROP TABLE #tmpBettrans
	DROP TABLE #tmpMatch
END
GO