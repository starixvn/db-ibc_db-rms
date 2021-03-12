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


	DECLARE @Selection TABLE (matchid INT, bettype INT, betteam NVARCHAR(10))
	DECLARE @result TABLE (transid BIGINT PRIMARY KEY, cnt INT)


	INSERT INTO @Selection (matchid, bettype, betteam)
	SELECT a.matchid, a.bettype, a.betteam
	FROM bodb02.dbo.bettransm a WITH (NOLOCK)
		INNER JOIN bodb02.dbo.match m WITH (NOLOCK) ON a.matchid = m.matchid
	WHERE a.refno = @refno AND a.winlostdate > @MoveBetsDay
	UNION
	SELECT a.matchid, a.bettype, a.betteam
	FROM bodb02.dbo.bettransm14 a WITH (NOLOCK)
		INNER JOIN bodb02.dbo.match14 m WITH (NOLOCK) ON a.matchid = m.matchid
	WHERE a.refno = @refno AND a.winlostdate BETWEEN @BalanceUpDay AND @MoveBetsDay	
	UNION
	SELECT a.matchid, a.bettype, a.betteam
	FROM dbo.bettransm a WITH (NOLOCK)
		INNER JOIN DBARC.bodb_Archive.dbo.match_bk m WITH (NOLOCK) ON a.matchid = m.matchid
	WHERE a.refno = @refno 

	DECLARE @bettrans TABLE (transid BIGINT PRIMARY KEY, refno BIGINT)

	INSERT INTO @bettrans(transid, refno)
	SELECT transid,refno
	FROM DBRMS.bodb_RMS.dbo.rmBettrans WITH (NOLOCK)
	WHERE bettype = 29
		AND combo = @combo
		AND statusID = 112
		AND winlostdate between DATEADD(DAY, -7, @winlostdate) AND  DATEADD(DAY, +7, @winlostdate)
		AND refno <> @refno
	UNION
	SELECT transid,refno
	FROM DBRMS.bodb_RMS.dbo.rmBettrans_Old WITH (NOLOCK)
	WHERE bettype = 29
		AND combo = @combo
		AND statusID = 112
		AND winlostdate between DATEADD(DAY, -7, @winlostdate) AND  DATEADD(DAY, +7, @winlostdate)
		AND refno <> @refno


	--INSERT INTO @result (transid, cnt)
	SELECT b.transid, COUNT(1)
	FROM @bettrans b
		CROSS APPLY (
			SELECT bm.matchid, bm.bettype, bm.betteam
			FROM bodb02.dbo.bettransm bm WITH (NOLOCK)
			WHERE bm.refno = b.refno AND bm.winlostdate > @MoveBetsDay
			UNION
			SELECT bm.matchid, bm.bettype, bm.betteam
			FROM bodb02.dbo.bettransm14 bm WITH (NOLOCK)
			WHERE bm.refno = b.refno AND bm.winlostdate BETWEEN @BalanceUpDay AND @MoveBetsDay
			UNION 
			SELECT arc.matchid, arc.bettype, arc.betteam
			FROM dbo.bettransm arc WITH (NOLOCK)
			WHERE arc.refno = b.refno  and arc.winlostdate < @BalanceUpDay
		) r
		INNER JOIN @Selection s ON r.matchid = s.matchid AND r.bettype = s.bettype AND r.betteam = s.betteam
	GROUP BY b.transid
	HAVING COUNT(1) >= CASE WHEN @combo = 2 THEN @combo ELSE (@combo * 1.0 / 2) END

	SELECT @cnt_bets = @@ROWCOUNT
	SELECT  @NumberWon = COUNT(1) FROM bodb02.dbo.bettransm WITH (NOLOCK) WHERE refno = @refno AND statusID = 112 AND winlostdate > @MoveBetsDay
	SELECT  @NumberWon = @NumberWon + COUNT(1) FROM bodb02.dbo.bettransm14 WITH (NOLOCK) WHERE refno = @refno AND statusID = 112 AND winlostdate BETWEEN @BalanceUpDay AND @MoveBetsDay
	SELECT  @NumberWon = @NumberWon + COUNT(1) FROM dbo.bettransm WITH (NOLOCK) WHERE refno = @refno AND statusID = 112 AND winlostdate < @BalanceUpDay

END

