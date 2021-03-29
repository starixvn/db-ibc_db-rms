/*<info serverAlias="DBARC-bodb_Archive" executers="bodbRMSNet" isFunction="0" isNested="1"></info>*/
ALTER PROCEDURE RMS_ARC_ComboParlayBetList_Sel @winlostdate SMALLDATETIME, @refno BIGINT, @combo INT, @statusID TINYINT,  @cnt_bets INT OUTPUT,  @NumberWon INT OUTPUT
AS
/*
	Created:
	DB: DBARC-bodb_Archive
	Task:  - Detail bettransm of parlay ticket archived

	Revisions:   
		- 20201221@danny: create SP  [RedmineID: #148137]
*/
SET NOCOUNT ON 
BEGIN

	DECLARE @MBU TABLE (BalanceUpDay SMALLDATETIME, MoveBetsDay SMALLDATETIME)
	INSERT INTO @MBU (BalanceUpDay, MoveBetsDay)
	EXEC bodb02.dbo.Age_SelBalanceUpDay

	DECLARE @BalanceUpDay SMALLDATETIME, @MoveBetsDay SMALLDATETIME
	SELECT  @BalanceUpDay = BalanceUpDay, @MoveBetsDay = MoveBetsDay FROM @MBU

	DECLARE @Selection TABLE (matchid INT, bettype INT, betteam NVARCHAR(10), winlostdate SMALLDATETIME)
	DECLARE @result TABLE (transid BIGINT PRIMARY KEY, cnt INT)

	INSERT INTO @Selection (matchid, bettype, betteam, winlostdate)
	SELECT a.matchid, a.bettype, a.betteam, a.winlostdate
	FROM bodb02.dbo.bettransm a WITH (NOLOCK)
	WHERE a.refno = @refno AND a.winlostdate > @MoveBetsDay
	UNION
	SELECT a.matchid, a.bettype, a.betteam, a.winlostdate
	FROM bodb02.dbo.bettransm14 a WITH (NOLOCK)
	WHERE a.refno = @refno AND a.winlostdate BETWEEN @BalanceUpDay AND @MoveBetsDay	
	UNION
	SELECT a.matchid, a.bettype, a.betteam, a.winlostdate
	FROM dbo.bettransm a WITH (NOLOCK)
	WHERE a.refno = @refno 

	CREATE TABLE #bettrans (transid BIGINT, refno BIGINT, winlostdate SMALLDATETIME)
	CREATE TABLE #result(refno BIGINT, cnt INT)
	CREATE CLUSTERED INDEX cix_#result ON #result(refno)

	INSERT INTO #bettrans(transid, refno, winlostdate)
	SELECT transid,refno, winlostdate 
	FROM DBRMS.bodb_RMS.dbo.rmBettrans WITH (NOLOCK)
	WHERE bettype = 29
		AND combo = @combo
		AND statusID = 112
		AND winlostdate between DATEADD(DAY, -20, @winlostdate) AND  DATEADD(DAY, +20, @winlostdate)
		AND refno <> @refno
	UNION
	SELECT transid,refno , winlostdate
	FROM DBRMS.bodb_RMS.dbo.rmBettrans_Old WITH (NOLOCK)
	WHERE bettype = 29
		AND combo = @combo
		AND statusID = 112
		AND winlostdate between DATEADD(DAY, -20, @winlostdate) AND  DATEADD(DAY, +20, @winlostdate)
		AND refno <> @refno

	CREATE CLUSTERED INDEX cix_#bettrans ON #bettrans(refno)

	CREATE TABLE #selection_filter(refno BIGINT)
	CREATE CLUSTERED INDEX cix_#selection_filter ON #selection_filter(refno)

	IF exists (SELECT 1 FROM @Selection WHERE winlostdate > @MoveBetsDay)
	BEGIN
		INSERT INTO #selection_filter (refno)
		SELECT bm.refno
		FROM  bodb02.dbo.bettransm  bm WITH(NOLOCK) 
		CROSS APPLY (SELECT 1 as col FROM @Selection s WHERE s.matchid = bm.matchid AND s.bettype = bm.bettype AND s.betteam = bm.betteam AND s.winlostdate = bm.winlostdate AND s.winlostdate > @MoveBetsDay) s

	END

	IF exists (SELECT 1 FROM @Selection WHERE winlostdate between @BalanceUpDay AND @MoveBetsDay)
	BEGIN
		INSERT INTO #selection_filter (refno)
		SELECT bm.refno
		FROM  bodb02.dbo.bettransm14  bm WITH(NOLOCK) 
		CROSS APPLY (SELECT 1 as col FROM @Selection s WHERE s.matchid = bm.matchid AND s.bettype = bm.bettype AND s.betteam = bm.betteam AND s.winlostdate = bm.winlostdate AND s.winlostdate between @BalanceUpDay AND @MoveBetsDay) s

	END

	IF exists (SELECT 1 FROM @Selection WHERE winlostdate < @BalanceUpDay)
	BEGIN
		INSERT INTO #selection_filter (refno)
		SELECT bm.refno
		FROM  dbo.bettransm  bm WITH(NOLOCK) 
		CROSS APPLY (SELECT 1 as col FROM @Selection s WHERE  s.winlostdate = bm.winlostdate AND s.matchid = bm.matchid AND s.bettype = bm.bettype AND s.betteam = bm.betteam  AND s.winlostdate < @BalanceUpDay) s
	END


	INSERT INTO #result(refno, cnt)
	SELECT refno, count(1) as cnt
	FROM #selection_filter 
	GROUP BY refno
	HAVING COUNT(1) >= CASE WHEN @combo = 2 THEN @combo ELSE (@combo * 1.0 / 2) END


	SELECT b.transid, x.cnt
	FROM #result x
	inner join #bettrans b ON x.refno = b.refno

	SELECT @cnt_bets = @@ROWCOUNT
	SELECT  @NumberWon = COUNT(1) FROM bodb02.dbo.bettransm WITH (NOLOCK) WHERE refno = @refno AND statusID = 112 AND winlostdate > @MoveBetsDay
	SELECT  @NumberWon = @NumberWon + COUNT(1) FROM bodb02.dbo.bettransm14 WITH (NOLOCK) WHERE refno = @refno AND statusID = 112 AND winlostdate BETWEEN @BalanceUpDay AND @MoveBetsDay
	SELECT  @NumberWon = @NumberWon + COUNT(1) FROM dbo.bettransm WITH (NOLOCK) WHERE refno = @refno AND statusID = 112 AND winlostdate < @BalanceUpDay

	DROP TABLE #selection_filter
	DROP TABLE #result
	DROP TABLE #bettrans


END

