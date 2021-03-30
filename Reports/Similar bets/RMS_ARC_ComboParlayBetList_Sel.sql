/*<info serverAlias="DBARC-bodb_Archive" executers="bodbRMSNet" isFunction="0" isNested="1"></info>*/
ALTER PROCEDURE RMS_ARC_ComboParlayBetList_Sel_danny @winlostdate SMALLDATETIME, @refno BIGINT, @combo INT, @statusID TINYINT,  @cnt_bets INT OUTPUT,  @NumberWon INT OUTPUT
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

	CREATE TABLE #bettrans (transid BIGINT, refno BIGINT)

	DECLARE @TSQL varchar(MAX)
	SELECT  @TSQL = 'SELECT transid,refno
					FROM OPENQUERY(DBRMS,''	SELECT transid,refno 
											FROM bodb_RMS.dbo.rmBettrans WITH (NOLOCK)
											WHERE bettype = 29
												AND combo = '+CAST(@combo as VARCHAR(10))+'
												AND statusID = 112
												AND winlostdate between DATEADD(DAY, -20, '''''+CONVERT(VARCHAR(50),@winlostdate,120)+''''') AND  DATEADD(DAY, +20,'''''+CONVERT(VARCHAR(50),@winlostdate,120)+''''')
												AND refno <> '+CAST(@refno AS VARCHAR(50))+'
											UNION
											SELECT transid,refno 
											FROM bodb_RMS.dbo.rmBettrans_Old WITH (NOLOCK)
											WHERE bettype = 29
												AND combo = '+CAST(@combo as VARCHAR(10))+'
												AND statusID = 112
												AND winlostdate between DATEADD(DAY, -20, '''''+CONVERT(VARCHAR(50),@winlostdate,120)+''''') AND  DATEADD(DAY, +20, '''''+CONVERT(VARCHAR(50),@winlostdate,120)+''''')
												AND refno <> '+CAST(@refno AS VARCHAR(50))+'
												'')'
	
	INSERT INTO #bettrans(transid, refno)
	EXEC (@TSQL)

	CREATE CLUSTERED INDEX cix_#bettrans ON #bettrans(refno)

	DECLARE @MaxRef BIGINT
	DECLARE @MinRef BIGINT

	SELECT @MaxRef = MAX(refno), @MinRef = MIN(refno) FROM #bettrans


	CREATE TABLE #temp (transid BIGINT, refno BIGINT)
	INSERT INTO #temp (transid, refno)
	select b.transid, b.refno
	FROM #bettrans b
	INNER JOIN  bodb02.dbo.bettransm bm WITH (NOLOCK) ON b.refno = bm.refno
	INNER JOIN @Selection s ON bm.matchid = s.matchid AND bm.bettype = s.bettype AND bm.betteam = s.betteam
	WHERE bm.refno between  @MinRef AND @MaxRef and bm.winlostdate > @MoveBetsDay AND s.winlostdate > @MoveBetsDay


	INSERT INTO #temp 
	select b.transid, b.refno
	FROM #bettrans b
	INNER JOIN  bodb02.dbo.bettransm14 bm WITH (NOLOCK) ON b.refno = bm.refno
	INNER JOIN @Selection s ON bm.matchid = s.matchid AND bm.bettype = s.bettype AND bm.betteam = s.betteam
	WHERE bm.refno between  @MinRef AND @MaxRef and bm.winlostdate between  @BalanceUpDay AND @MoveBetsDay  AND s.winlostdate  between  @BalanceUpDay AND @MoveBetsDay

	INSERT INTO #temp 
	select b.transid, b.refno
	FROM #bettrans b
	INNER JOIN  dbo.bettransm bm WITH (NOLOCK) ON b.refno = bm.refno
	INNER JOIN @Selection s ON bm.matchid = s.matchid AND bm.bettype = s.bettype AND bm.betteam = s.betteam
	WHERE bm.refno between  @MinRef AND @MaxRef and bm.winlostdate <  @BalanceUpDay   AND s.winlostdate  < @BalanceUpDay

	SELECT transid, count(1) as cnt
	FROM #temp
	GROUP BY transid
	HAVING COUNT(1) >= CASE WHEN @combo = 2 THEN @combo ELSE (@combo * 1.0 / 2) END


	SELECT @cnt_bets = @@ROWCOUNT
	SELECT  @NumberWon = COUNT(1) FROM bodb02.dbo.bettransm WITH (NOLOCK) WHERE refno = @refno AND statusID = 112 AND winlostdate > @MoveBetsDay
	SELECT  @NumberWon = @NumberWon + COUNT(1) FROM bodb02.dbo.bettransm14 WITH (NOLOCK) WHERE refno = @refno AND statusID = 112 AND winlostdate BETWEEN @BalanceUpDay AND @MoveBetsDay
	SELECT  @NumberWon = @NumberWon + COUNT(1) FROM dbo.bettransm WITH (NOLOCK) WHERE refno = @refno AND statusID = 112 AND winlostdate < @BalanceUpDay

	DROP TABLE #temp
	DROP TABLE #bettrans
END

