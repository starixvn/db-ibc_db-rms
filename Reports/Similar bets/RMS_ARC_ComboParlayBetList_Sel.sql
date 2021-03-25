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
	WHERE a.refno = @refno AND a.winlostdate > @MoveBetsDay
	UNION
	SELECT a.matchid, a.bettype, a.betteam
	FROM bodb02.dbo.bettransm14 a WITH (NOLOCK)
	WHERE a.refno = @refno AND a.winlostdate BETWEEN @BalanceUpDay AND @MoveBetsDay	
	UNION
	SELECT a.matchid, a.bettype, a.betteam
	FROM dbo.bettransm a WITH (NOLOCK)
	WHERE a.refno = @refno 

	DECLARE @bettrans TABLE (transid BIGINT PRIMARY KEY, refno BIGINT)

	CREATE TABLE #bettrans (transid BIGINT, refno BIGINT, winlostdate SMALLDATETIME, combo INT, combo_byRange INT)
	CREATE TABLE #result(refno BIGINT, transid BIGINT, cnt INT, combo INT)
	CREATE CLUSTERED INDEX cix_#result ON #result(refno)

	INSERT INTO #bettrans(transid, refno, winlostdate, combo_byRange)
	SELECT transid,refno, winlostdate , 0
	FROM DBRMS.bodb_RMS.dbo.rmBettrans WITH (NOLOCK)
	WHERE bettype = 29
		AND combo = @combo
		AND statusID = 112
		AND winlostdate between DATEADD(DAY, -7, @winlostdate) AND  DATEADD(DAY, +7, @winlostdate)
		AND refno <> @refno
	UNION
	SELECT transid,refno , winlostdate, 0
	FROM DBRMS.bodb_RMS.dbo.rmBettrans_Old WITH (NOLOCK)
	WHERE bettype = 29
		AND combo = @combo
		AND statusID = 112
		AND winlostdate between DATEADD(DAY, -7, @winlostdate) AND  DATEADD(DAY, +7, @winlostdate)
		AND refno <> @refno

	CREATE CLUSTERED INDEX cix_#bettrans ON #bettrans(refno)
	CREATE INDEX idx_#bettrans ON #bettrans(winlostdate)


	-- Handle mainticket on range bettrans
	IF exists (SELECT 1 FROM #bettrans WHERE winlostdate > @MoveBetsDay)
	BEGIN
		INSERT INTO #result(refno, transid, combo, cnt)
		SELECT b.refno, b.transid, COUNT(1) as combo, SUM(cnt) as cnt
		FROM (
			SELECT  b.refno, b.transid, CASE WHEN  s.matchid IS NOT NULL AND s.bettype IS NOT NULL AND s.betteam  IS NOT NULL THEN 1 ELSE 0 END cnt
			FROM #bettrans b
			INNER JOIN bodb02.dbo.bettransm bm WITH (NOLOCK) ON bm.refno = b.refno
			LEFT JOIN @Selection s ON bm.matchid = s.matchid AND bm.bettype = s.bettype AND bm.betteam = s.betteam
			WHERE  b.winlostdate > @MoveBetsDay AND  bm.winlostdate > @MoveBetsDay 
		) b
		GROUP BY b.refno, b.transid

		UPDATE t
		SET t.combo_byRange = t.combo_byRange + ISNULL(r.combo,0)
		FROM #bettrans t
		INNER JOIN #result r ON t.refno = r.refno AND t.winlostdate > @MoveBetsDay

		DELETE  t
		FROM #bettrans t
		WHERE t.winlostdate > @MoveBetsDay AND t.combo_byRange = @combo

		-- Scan bettrans14
		IF Exists (SELECT 1 FROM #bettrans WHERE winlostdate > @MoveBetsDay)
		BEGIN
			INSERT INTO #result(refno, transid, combo, cnt)
			SELECT b.refno, b.transid, COUNT(1) as combo, SUM(cnt) as cnt
			FROM (
				SELECT  b.refno, b.transid, CASE WHEN  s.matchid IS NOT NULL AND s.bettype IS NOT NULL AND s.betteam  IS NOT NULL THEN 1 ELSE 0 END cnt
				FROM #bettrans b
				INNER JOIN bodb02.dbo.bettransm14 bm WITH (NOLOCK) ON bm.refno = b.refno
				LEFT JOIN @Selection s ON bm.matchid = s.matchid AND bm.bettype = s.bettype AND bm.betteam = s.betteam
				WHERE  b.winlostdate > @MoveBetsDay AND  bm.winlostdate BETWEEN @BalanceUpDay AND @MoveBetsDay
			) b
			GROUP BY b.refno, b.transid

			UPDATE t
			SET t.combo_byRange = t.combo_byRange + ISNULL(r.combo,0)
			FROM #bettrans t
			INNER JOIN #result r ON t.refno = r.refno AND t.winlostdate > @MoveBetsDay

			DELETE  t
			FROM #bettrans t
			WHERE t.winlostdate > @MoveBetsDay AND t.combo_byRange = @combo

		END

		-- Scan bettrans_bk
		IF Exists (SELECT 1 FROM #bettrans WHERE winlostdate > @MoveBetsDay)
		BEGIN
			INSERT INTO #result(refno, transid, combo, cnt)
			SELECT b.refno, b.transid, COUNT(1) as combo, SUM(cnt) as cnt
			FROM (
				SELECT  b.refno, b.transid, CASE WHEN  s.matchid IS NOT NULL AND s.bettype IS NOT NULL AND s.betteam  IS NOT NULL THEN 1 ELSE 0 END cnt
				FROM #bettrans b
				INNER JOIN dbo.bettransm bm WITH (NOLOCK) ON bm.refno = b.refno
				LEFT JOIN @Selection s ON bm.matchid = s.matchid AND bm.bettype = s.bettype AND bm.betteam = s.betteam
				WHERE  b.winlostdate > @MoveBetsDay AND  bm.winlostdate < @BalanceUpDay
			) b
			GROUP BY b.refno, b.transid

			UPDATE t
			SET t.combo_byRange = t.combo_byRange + ISNULL(r.combo,0)
			FROM #bettrans t
			INNER JOIN #result r ON t.refno = r.refno AND t.winlostdate > @MoveBetsDay

			DELETE  t
			FROM #bettrans t
			WHERE t.winlostdate > @MoveBetsDay AND t.combo_byRange = @combo

		END
	END

	-- Handle mainticket on range bettrans14
	IF exists (SELECT 1 FROM #bettrans WHERE winlostdate between @BalanceUpDay AND @MoveBetsDay)
	BEGIN
		-- Scan bettrans14
		INSERT INTO #result(refno, transid, combo, cnt)
		SELECT b.refno, b.transid, COUNT(1) as combo, SUM(cnt) as cnt
		FROM (
			SELECT  b.refno, b.transid, CASE WHEN  s.matchid IS NOT NULL AND s.bettype IS NOT NULL AND s.betteam  IS NOT NULL THEN 1 ELSE 0 END cnt
			FROM #bettrans b
			INNER JOIN bodb02.dbo.bettransm14 bm WITH (NOLOCK) ON bm.refno = b.refno
			LEFT JOIN @Selection s ON bm.matchid = s.matchid AND bm.bettype = s.bettype AND bm.betteam = s.betteam
			WHERE  b.winlostdate between @BalanceUpDay AND @MoveBetsDay AND  bm.winlostdate BETWEEN @BalanceUpDay AND @MoveBetsDay
		) b
		GROUP BY b.refno, b.transid

		UPDATE t
		SET t.combo_byRange = t.combo_byRange + ISNULL(r.combo,0)
		FROM #bettrans t
		INNER JOIN #result r ON t.refno = r.refno AND t.winlostdate between @BalanceUpDay AND @MoveBetsDay

		DELETE  t
		FROM #bettrans t
		WHERE t.winlostdate  between @BalanceUpDay AND @MoveBetsDay AND t.combo_byRange = @combo

		
		-- Scan bettrans_bk
		IF Exists (SELECT 1 FROM #bettrans WHERE winlostdate between @BalanceUpDay AND @MoveBetsDay)
		BEGIN
			INSERT INTO #result(refno, transid, combo, cnt)
			SELECT b.refno, b.transid, COUNT(1) as combo, SUM(cnt) as cnt
			FROM (
				SELECT  b.refno, b.transid, CASE WHEN  s.matchid IS NOT NULL AND s.bettype IS NOT NULL AND s.betteam  IS NOT NULL THEN 1 ELSE 0 END cnt
				FROM #bettrans b
				INNER JOIN dbo.bettransm bm WITH (NOLOCK) ON bm.refno = b.refno
				LEFT JOIN @Selection s ON bm.matchid = s.matchid AND bm.bettype = s.bettype AND bm.betteam = s.betteam
				WHERE  b.winlostdate between @BalanceUpDay AND @MoveBetsDay AND  bm.winlostdate < @BalanceUpDay
			) b
			GROUP BY b.refno, b.transid

			UPDATE t
			SET t.combo_byRange = t.combo_byRange + ISNULL(r.combo,0)
			FROM #bettrans t
			INNER JOIN #result r ON t.refno = r.refno AND t.winlostdate between @BalanceUpDay AND @MoveBetsDay

			DELETE  t
			FROM #bettrans t
			WHERE t.winlostdate  between @BalanceUpDay AND @MoveBetsDay  AND t.combo_byRange = @combo

		END
	END

	-- Handle mainticket on range bettrans_bk
	IF exists (SELECT 1 FROM #bettrans WHERE winlostdate < @BalanceUpDay)
	BEGIN
		-- Scan bettrans_bk
		INSERT INTO #result(refno, transid, combo, cnt)
		SELECT b.refno, b.transid, COUNT(1) as combo, SUM(cnt) as cnt
		FROM (
			SELECT  b.refno, b.transid, CASE WHEN  s.matchid IS NOT NULL AND s.bettype IS NOT NULL AND s.betteam  IS NOT NULL THEN 1 ELSE 0 END cnt
			FROM #bettrans b
			INNER JOIN dbo.bettransm bm WITH (NOLOCK) ON bm.refno = b.refno
			LEFT JOIN @Selection s ON bm.matchid = s.matchid AND bm.bettype = s.bettype AND bm.betteam = s.betteam
			WHERE  b.winlostdate < @BalanceUpDay AND  bm.winlostdate < @BalanceUpDay
		) b
		GROUP BY b.refno, b.transid

		UPDATE t
		SET t.combo_byRange = t.combo_byRange + ISNULL(r.combo,0)
		FROM #bettrans t
		INNER JOIN #result r ON t.refno = r.refno AND t.winlostdate < @BalanceUpDay

		DELETE  t
		FROM #bettrans t
		WHERE t.winlostdate < @BalanceUpDay AND t.combo_byRange = @combo
	END

	----INSERT INTO @result (transid, cnt)
	--SELECT b.transid, COUNT(1) as cnt
	--FROM #bettrans b
	--	CROSS APPLY (
	--		SELECT bm.matchid, bm.bettype, bm.betteam
	--		FROM bodb02.dbo.bettransm bm WITH (NOLOCK)
	--		--INNER JOIN @Selection s ON bm.matchid = s.matchid AND bm.bettype = s.bettype AND bm.betteam = s.betteam
	--		WHERE bm.refno = b.refno AND bm.winlostdate > @MoveBetsDay
	--		UNION
	--		SELECT bm.matchid, bm.bettype, bm.betteam
	--		FROM bodb02.dbo.bettransm14 bm WITH (NOLOCK)
	--		--INNER JOIN @Selection s ON bm.matchid = s.matchid AND bm.bettype = s.bettype AND bm.betteam = s.betteam
	--		WHERE bm.refno = b.refno AND bm.winlostdate BETWEEN @BalanceUpDay AND @MoveBetsDay
	--		UNION 
	--		SELECT arc.matchid, arc.bettype, arc.betteam
	--		FROM dbo.bettransm arc WITH (NOLOCK)
	--		--INNER JOIN @Selection s ON arc.matchid = s.matchid AND arc.bettype = s.bettype AND arc.betteam = s.betteam
	--		WHERE arc.refno = b.refno  and arc.winlostdate < @BalanceUpDay
	--	) r
	--INNER JOIN  @Selection s ON r.matchid = s.matchid AND r.bettype = s.bettype AND r.betteam = s.betteam
	--GROUP BY b.transid
	--HAVING COUNT(1) >= CASE WHEN @combo = 2 THEN @combo ELSE (@combo * 1.0 / 2) END


	SELECT b.transid, SUM(cnt) as cnt
	FROM #result b
	GROUP BY b.transid
	HAVING SUM(cnt) >= CASE WHEN @combo = 2 THEN @combo ELSE (@combo * 1.0 / 2) END

	SELECT @cnt_bets = @@ROWCOUNT
	SELECT  @NumberWon = COUNT(1) FROM bodb02.dbo.bettransm WITH (NOLOCK) WHERE refno = @refno AND statusID = 112 AND winlostdate > @MoveBetsDay
	SELECT  @NumberWon = @NumberWon + COUNT(1) FROM bodb02.dbo.bettransm14 WITH (NOLOCK) WHERE refno = @refno AND statusID = 112 AND winlostdate BETWEEN @BalanceUpDay AND @MoveBetsDay
	SELECT  @NumberWon = @NumberWon + COUNT(1) FROM dbo.bettransm WITH (NOLOCK) WHERE refno = @refno AND statusID = 112 AND winlostdate < @BalanceUpDay


	DROP TABLE #result
	DROP TABLE #bettrans

END

