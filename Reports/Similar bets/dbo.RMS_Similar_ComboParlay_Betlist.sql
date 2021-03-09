/*<info serverAlias="DBRMS-bodb_RMS" executers="bodbRMSNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[RMS_Similar_ComboParlay_Betlist]
	@transid BIGINT
AS

/*
	Created: 20160426@Winnie
	DB: DBRMS-bodb_RMS
	Task: Get similar bets combo parlay tickets
			
	Revisions:
		- 20160927@Winnie: fix issue conflict refno with racing RedmineID: #64286
		- 20170719@Winnie: Add MuayThai RedmineID: #79500
		- 20190214@Jacob: Add Bet Builder RedmineID: #108694
		- 20200510@Percy: Add Penalty Shootout Combo [RedmineID: #133961]
		- 20200821@Percy: Fix issue duplicate data due to MBBU process [RedmineID: #140078]
		- 20201105@Percy: Include data from yesterday [RedmineID: #144905]
		- 20201204@Danny: Separate Data of Virtual Soccer & Virtual Basketball  [RedmineID: #145926]
		- 20210218@Danny: Monitor Performance of GOF  [RedmineID: #149966]
		- 20210303@Danny: Add Filter won ticket  [RedmineID: #148137]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @MBU TABLE (BalanceUpDay SMALLDATETIME, MoveBetsDay SMALLDATETIME)
	INSERT INTO @MBU (BalanceUpDay, MoveBetsDay)
	EXEC bodb02.dbo.Age_SelBalanceUpDay

	DECLARE @BalanceUpDay SMALLDATETIME, @MoveBetsDay SMALLDATETIME
	SELECT  @BalanceUpDay = BalanceUpDay, @MoveBetsDay = MoveBetsDay FROM @MBU

	DECLARE @bettype INT, @betteam NVARCHAR(10), @matchid INT, @refno BIGINT, @combo INT, @cnt_bets INT, @yesterday DATETIME, @statusID TINYINT, @winlostdate SMALLDATETIME, @betcheck NVARCHAR(50)

	SELECT @yesterday = CONVERT(DATE, DATEADD(DAY, -1, GETDATE()))

	SELECT @bettype = t.bettype, @betteam = t.betteam, @matchid = t.matchid, @refno = t.refno, @combo = t.hdp2, @statusID = t.statusID, @winlostdate = t.winlostdate, @betcheck = t.betcheck
	FROM
	(
		SELECT bettype, betteam, matchid, refno, hdp2, statusID, winlostdate, betcheck
		FROM dbo.rmBettrans WITH (NOLOCK) WHERE transid = @transid
		UNION ALL
		SELECT bettype, betteam, matchid, refno, hdp2, statusID, winlostdate, betcheck
		FROM dbo.rmBettrans_Old WITH (NOLOCK) WHERE transid = @transid
	) t

	IF (@@ROWCOUNT = 0 OR @statusID IN (111, 113) )
		RETURN

	DECLARE @result TABLE (transid BIGINT PRIMARY KEY, cnt INT)

	IF @bettype = 29
	BEGIN
		DECLARE @Selection TABLE (matchid INT, bettype INT, betteam NVARCHAR(10))
		DECLARE @bettrans TABLE (transid BIGINT PRIMARY KEY, refno BIGINT)
		DECLARE @NumberWon INT

		IF @statusID = 0 
		BEGIN
			INSERT INTO @Selection (matchid, bettype, betteam)
			SELECT a.matchid, a.bettype, a.betteam
			FROM bodb02.dbo.bettransm a WITH (NOLOCK)
				INNER JOIN bodb02.dbo.match m WITH (NOLOCK) ON a.matchid = m.matchid
			WHERE a.refno = @refno AND (a.statusID IN (0, 1) OR a.winlostdate > @MoveBetsDay)
			UNION
			SELECT a.matchid, a.bettype, a.betteam
			FROM bodb02.dbo.bettransm14 a WITH (NOLOCK)
				INNER JOIN bodb02.dbo.match14 m WITH (NOLOCK) ON a.matchid = m.matchid
			WHERE a.refno = @refno AND a.winlostdate BETWEEN @BalanceUpDay AND @MoveBetsDay

			INSERT INTO @bettrans (transid, refno)
			SELECT transid, refno
			FROM dbo.rmBettrans WITH (NOLOCK)
			WHERE bettype = 29
				AND combo = @combo
				AND statusID = @statusID
				AND winlostdate >= @yesterday
				AND refno <> @refno

			INSERT INTO @result (transid, cnt)
			SELECT b.transid, COUNT(1)
			FROM @bettrans b
				CROSS APPLY (
					SELECT bm.matchid, bm.bettype, bm.betteam
					FROM bodb02.dbo.bettransm bm WITH (NOLOCK)
					WHERE bm.refno = b.refno AND (bm.statusID IN (0, 1) OR bm.winlostdate > @MoveBetsDay)
					UNION
					SELECT bm.matchid, bm.bettype, bm.betteam
					FROM bodb02.dbo.bettransm14 bm WITH (NOLOCK)
					WHERE bm.refno = b.refno AND bm.winlostdate BETWEEN @BalanceUpDay AND @MoveBetsDay
				) r
				INNER JOIN @Selection s ON r.matchid = s.matchid AND r.bettype = s.bettype AND r.betteam = s.betteam
			GROUP BY b.transid
			HAVING COUNT(1) >= CASE WHEN @combo = 2 THEN @combo ELSE (@combo * 1.0 / 2) END

			SELECT @cnt_bets = @@ROWCOUNT
			SELECT  @NumberWon = COUNT(1) FROM bodb02.dbo.bettransm WITH (NOLOCK) WHERE refno = @refno AND statusID = 112 AND winlostdate > @MoveBetsDay
			SELECT  @NumberWon = @NumberWon + COUNT(1) FROM bodb02.dbo.bettransm14 WITH (NOLOCK) WHERE refno = @refno AND statusID = 112 AND winlostdate BETWEEN @BalanceUpDay AND @MoveBetsDay
		END
	
		IF @statusID = 112
		BEGIN
			IF @winlostdate between  @MoveBetsDay AND @BalanceUpDay
			BEGIN
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
				
				INSERT INTO @Selection (matchid, bettype, betteam)
				SELECT a.matchid, a.bettype, a.betteam
				FROM DBARC.bodb_Archive.dbo.bettransm a WITH (NOLOCK)
					INNER JOIN DBARC.bodb_Archive.dbo.match_bk m WITH (NOLOCK) ON a.matchid = m.matchid
				WHERE a.refno = @refno 
			END

			IF @winlostdate >  @MoveBetsDay 
			BEGIN
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
			END

			IF @winlostdate < @BalanceUpDay
			BEGIN

				INSERT INTO @Selection (matchid, bettype, betteam)
				SELECT a.matchid, a.bettype, a.betteam
				FROM bodb02.dbo.bettransm14 a WITH (NOLOCK)
					INNER JOIN bodb02.dbo.match14 m WITH (NOLOCK) ON a.matchid = m.matchid
				WHERE a.refno = @refno AND a.winlostdate BETWEEN @BalanceUpDay AND @MoveBetsDay
				UNION
				
				SELECT a.matchid, a.bettype, a.betteam
				FROM DBARC.bodb_Archive.dbo.bettransm a WITH (NOLOCK)
					INNER JOIN DBARC.bodb_Archive.dbo.match_bk m WITH (NOLOCK) ON a.matchid = m.matchid
				WHERE a.refno = @refno 
			END

			-- get transid list
			INSERT INTO @bettrans (transid, refno)
			SELECT transid, refno
			FROM dbo.rmBettrans WITH (NOLOCK)
			WHERE bettype = 29
				AND combo = @combo
				AND statusID = @statusID
				AND winlostdate between DATEADD(DAY, -7, @winlostdate) AND  DATEADD(DAY, +7, @winlostdate)
				AND refno <> @refno

			INSERT INTO @bettrans (transid, refno)
			SELECT transid, refno
			FROM dbo.rmBettrans_Old WITH (NOLOCK)
			WHERE bettype = 29
				AND combo = @combo
				AND statusID = @statusID
				AND winlostdate between DATEADD(DAY, -7, @winlostdate) AND  DATEADD(DAY, +7, @winlostdate)
				AND refno <> @refno
			-- END get transid list


			CREATE TABLE #match_bk (refno BIGINT, matchid INT, bettype INT, betteam NVARCHAR(10))

			INSERT INTO #match_bk (refno, matchid, bettype, betteam)
			SELECT bm.refno, bm.matchid, bm.bettype, bm.betteam
			FROM DBARC.bodb_Archive.dbo.bettransm bm
			WHERE bm.winlostdate BETWEEN DATEADD(DAY, -14, @winlostdate) AND  DATEADD(DAY, +14, @winlostdate) AND  statusID IN (112,113)

			CREATE CLUSTERED INDEX cix_#refno ON #match_bk(refno)

			INSERT INTO @result (transid, cnt)
			SELECT b.transid, COUNT(1)
			FROM @bettrans b
				CROSS APPLY (
					SELECT bm.matchid, bm.bettype, bm.betteam
					FROM bodb02.dbo.bettransm bm WITH (NOLOCK)
					WHERE bm.refno = b.refno AND (bm.statusID IN (0, 1) OR bm.winlostdate > @MoveBetsDay)
					UNION
					SELECT bm.matchid, bm.bettype, bm.betteam
					FROM bodb02.dbo.bettransm14 bm WITH (NOLOCK)
					WHERE bm.refno = b.refno AND bm.winlostdate BETWEEN @BalanceUpDay AND @MoveBetsDay
					UNION 
					SELECT bm.matchid, bm.bettype, bm.betteam
					FROM #match_bk bm
					WHERE bm.refno = b.refno 
				) r
				INNER JOIN @Selection s ON r.matchid = s.matchid AND r.bettype = s.bettype AND r.betteam = s.betteam
			GROUP BY b.transid
			HAVING COUNT(1) >= CASE WHEN @combo = 2 THEN @combo ELSE (@combo * 1.0 / 2) END

			SELECT @cnt_bets = @@ROWCOUNT
			SELECT  @NumberWon = COUNT(1) FROM bodb02.dbo.bettransm WITH (NOLOCK) WHERE refno = @refno AND statusID = 112 AND winlostdate > @MoveBetsDay
			SELECT  @NumberWon = @NumberWon + COUNT(1) FROM bodb02.dbo.bettransm14 WITH (NOLOCK) WHERE refno = @refno AND statusID = 112 AND winlostdate BETWEEN @BalanceUpDay AND @MoveBetsDay
			SELECT  @NumberWon = @NumberWon + COUNT(1) FROM DBARC.bodb_Archive.dbo.bettransm WITH (NOLOCK) WHERE refno = @refno AND statusID = 112 

		END

	END
	ELSE IF @bettype = 38
	BEGIN
		DECLARE @OriginalSMP_Selection TABLE (transid BIGINT, SelectionType INT)
		DECLARE @SMP_Selection TABLE (transid BIGINT, SelectionType INT)
		

		INSERT INTO @OriginalSMP_Selection (TransId, SelectionType)
		SELECT b.transid, a.SelectionType
		FROM dbo.rmBettrans b WITH (NOLOCK)
			INNER JOIN bodb02.dbo.SMP_MarketSelection a WITH (NOLOCK) ON b.betcheck = a.MarketId
		WHERE b.transid = @transid
		UNION 
		SELECT b.transid, a.SelectionType
		FROM dbo.rmBettrans_Old b WITH (NOLOCK)
			INNER JOIN bodb02.dbo.SMP_MarketSelection a WITH (NOLOCK) ON b.betcheck = a.MarketId
		WHERE b.transid = @transid
			
		IF @winlostdate > @MoveBetsDay
		BEGIN
			INSERT INTO @SMP_Selection (TransId, SelectionType)
			SELECT b.transid, a.SelectionType
			FROM dbo.rmBettrans b WITH (NOLOCK)
				INNER JOIN bodb02.dbo.SMP_MarketSelection a WITH (NOLOCK) ON b.betcheck = a.MarketId
			WHERE b.hdp2 = @combo 		
				AND statusid = @statusID
				AND a.matchid = @MatchId
				AND winlostdate >= @yesterday
				AND b.transid <> @transid
		END
		ELSE 
		BEGIN
			INSERT INTO @SMP_Selection (TransId, SelectionType)
			SELECT b.transid, a.SelectionType
			FROM dbo.rmBettrans_Old b WITH (NOLOCK)
				INNER JOIN bodb02.dbo.SMP_MarketSelection a WITH (NOLOCK) ON b.betcheck = a.MarketId
			WHERE b.hdp2 = @combo 		
				AND statusid = @statusID
				AND a.matchid = @MatchId
				AND winlostdate = @winlostdate
				AND b.transid <> @transid
		END

		INSERT INTO @result (transid, cnt)
		SELECT s.transid, COUNT(1)
		FROM @OriginalSMP_Selection r
			INNER JOIN @SMP_Selection s ON r.SelectionType = s.SelectionType
		GROUP BY s.transid
		HAVING COUNT(1) >= CASE WHEN @combo = 2 THEN @combo ELSE (@combo * 1.0 / 2) END

		
	END
	ELSE IF @bettype = 376
	BEGIN
		DECLARE @Similar_Selection TABLE (transid BIGINT, betteam NVARCHAR(10))

		IF @winlostdate > @MoveBetsDay
		BEGIN
			INSERT INTO @Similar_Selection (transid, betteam)
			SELECT transid, betteam
			FROM dbo.rmBettrans WITH (NOLOCK)
			WHERE hdp2 = @combo
				AND statusID = @statusID
				AND matchid = @matchid
				AND winlostdate >= @yesterday
				AND transid <> @transid
		END 
		ELSE
		BEGIN
			INSERT INTO @Similar_Selection (transid, betteam)
			SELECT transid, betteam
			FROM dbo.rmBettrans_Old WITH (NOLOCK)
			WHERE hdp2 = @combo
				AND statusID = @statusID
				AND matchid = @matchid
				AND winlostdate = @yesterday
				AND transid <> @transid
		END

		;WITH CTE_number AS
		(
			SELECT 1 AS number
			UNION ALL
			SELECT number + 1
			FROM CTE_number
			WHERE number < LEN(@betteam)
		)
		INSERT INTO @result (transid, cnt)
		SELECT s.transid, SUM(CASE WHEN SUBSTRING(@betteam, n.number, 1) <> '-' AND SUBSTRING(@betteam, n.number, 1) = SUBSTRING(s.betteam, n.number, 1) THEN 1 ELSE 0 END)
		FROM @Similar_Selection s
			CROSS JOIN CTE_number n
		GROUP BY s.transid
		HAVING SUM(CASE WHEN SUBSTRING(@betteam, n.number, 1) <> '-' AND SUBSTRING(@betteam, n.number, 1) = SUBSTRING(s.betteam, n.number, 1) THEN 1 ELSE 0 END)
				>= CASE WHEN @combo = 2 THEN 2 ELSE @combo * 1.0 / 2 END
		OPTION (MAXRECURSION 0)
	END

	-- Return data
	SELECT @cnt_bets = COUNT(1) FROM @result

	IF @statusID = 0 
	BEGIN
		SELECT
			p.transdate
			,p.transid
			,p.refno
			,p.username
			,p.custid
			,p.bettype
			,ISNULL(c.level, 0) AS level
			,CASE WHEN p.transid2 NOT IN (-1,-3,1,2,3,4,5,6,7,8,9,11,43,44,-4,-5) THEN -2 ELSE p.transid2 END AS Sporttype
			,p.odds2 * p.TotalBet AS odds
			,(p.stake * p.actualrate * (1 - p.tpositiontaking) / p.TotalBet) AS stake
			,(p.stake * (p.odds2 - 1) * p.actualrate * (1 - p.tpositiontaking)) AS net_win
			,p.hdp2		AS TotalSelection
			,ISNULL(@NumberWon, 0)	AS NumberWon
			,p.TotalBet	AS TotalBet
			,@cnt_bets	AS cnt_bets,
			CAST(CASE WHEN p.bettype = 29 AND p.betteam= N'1' AND p.oddsspread = 1 THEN 1 ELSE 0 END AS BIT) AS IsGOF
			,p.statusID as statusID

		FROM dbo.rmBettrans p WITH (NOLOCK) 
			LEFT JOIN rmCustomer c WITH (NOLOCK) ON p.custid = c.custid
		WHERE transid = @transid

		SELECT
			p.transid
			,p.refno
			,p.username
			,p.custid
			,ISNULL(c.level, 0) AS level
			,CASE WHEN @statusID = 0  THEN stake * (odds2 - 1) * actualrate * (1 - p.tpositiontaking) ELSE ((p.winlost - p.actual_stake) * p.actualrate) END  AS net_win
			,cnt AS similar_selection
		FROM @result r
			INNER JOIN dbo.rmBettrans p WITH (NOLOCK) ON r.transid = p.transid
			LEFT JOIN rmCustomer c WITH (NOLOCK) ON p.custid = c.custid
		ORDER BY cnt DESC
	END

	IF @statusID = 112
	BEGIN
		SELECT
			p.transdate
			,p.transid
			,p.refno
			,p.username
			,p.custid
			,p.bettype
			,ISNULL(c.level, 0) AS level
			,CASE WHEN p.transid2 NOT IN (-1,-3,1,2,3,4,5,6,7,8,9,11,43,44,-4,-5) THEN -2 ELSE p.transid2 END AS Sporttype
			,p.odds2 * p.TotalBet AS odds
			,CASE WHEN @statusID = 0  THEN (p.stake * p.actualrate * (1 - p.tpositiontaking) / p.TotalBet)
			ELSE (p.stake * (1 - p.tpositiontaking - CONVERT(DECIMAL(9, 8), ISNULL(p.epositiontaking, 0))) * p.actualrate)  END AS stake
			,CASE WHEN @statusID = 0  THEN (p.stake * (p.odds2 - 1) * p.actualrate * (1 - p.tpositiontaking))
			ELSE  ((p.winlost - p.actual_stake) * p.actualrate)  END AS net_win
			,p.hdp2		AS TotalSelection
			,ISNULL(@NumberWon, 0)	AS NumberWon
			,p.TotalBet	AS TotalBet
			,@cnt_bets	AS cnt_bets,
			CAST(CASE WHEN p.bettype = 29 AND p.betteam= N'1' AND p.oddsspread = 1 THEN 1 ELSE 0 END AS BIT) AS IsGOF
			,p.statusID as statusID

		FROM dbo.rmBettrans p WITH (NOLOCK) 
			LEFT JOIN rmCustomer c WITH (NOLOCK) ON p.custid = c.custid
		WHERE transid = @transid

		SELECT
			p.transid
			,p.refno
			,p.username
			,p.custid
			,ISNULL(c.level, 0) AS level
			,CASE WHEN @statusID = 0  THEN stake * (odds2 - 1) * actualrate * (1 - p.tpositiontaking) ELSE ((p.winlost - p.actual_stake) * p.actualrate) END  AS net_win
			,cnt AS similar_selection
		FROM @result r
			INNER JOIN dbo.rmBettrans p WITH (NOLOCK) ON r.transid = p.transid
			LEFT JOIN rmCustomer c WITH (NOLOCK) ON p.custid = c.custid
		ORDER BY cnt DESC
	END


END
GO