/*<info serverAlias="DBRMS-bodb_RMS" executers="wsv_rms" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[RMS_Similar_ComboParlay_Betlist]
	@transid BIGINT,
	@isSimilar BIT = 0 --100%
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
		- 20210628@Danny: Add Column Member Potential Winning [RedmineID: #156979]
		- 20210629@Danny: Add filtering by Customer Class[RedmineID: #156980]
		- 20210029@Danny: Support filter tickets having 100% of selections Similar Bets [RedmineID: #159304]
		- 20230320@Cherry: Change formula of Stake (#185251)
		- 20230417@Cherry: Duplicate data Similar Bet (#186993)
		- 20230420@Cherry: Add Site column (#186735)
		- 20231020@Cherry: Parlay Generator (#195498)
		- 20231115@Cherry: Add IP column (#196550)
		- 20240102@Cherry: Parlay Type for Parlay Boost (#199217)
		- 20240115@Cherry: Change attribute for Parlay Generator (#199766)
		- 20240312@Cherry: Change SQL account in metadata (#202012)
		- 20241204@Cherry: Show tracking user (#212544)
		- 20241212@Cherry: Separate Cricket (#214664)
		- 20251016@Cherry: Move sites NovaCasino, SEAL888 from Deposit to Credit (#241763)
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
		UNION 
		SELECT bettype, betteam, matchid, refno, hdp2, statusID, winlostdate, betcheck
		FROM dbo.rmBettrans_Old WITH (NOLOCK) WHERE transid = @transid
	) t


	DECLARE @filter INT 
	SELECT @filter = CASE WHEN @isSimilar = 0 THEN CASE WHEN @combo = 2 THEN @combo ELSE CEILING(@combo * 1.0 / 2) END ELSE @combo END

	IF (@@ROWCOUNT = 0 OR @statusID IN (111, 113) OR @winlostdate < @BalanceUpDay)
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
			WHERE a.refno = @refno AND (a.winlostdate IS NULL OR a.winlostdate > @MoveBetsDay)
			UNION ALL
			SELECT a.matchid, a.bettype, a.betteam
			FROM bodb02.dbo.bettransm14 a WITH (NOLOCK)
			WHERE a.refno = @refno AND a.winlostdate BETWEEN @BalanceUpDay AND @MoveBetsDay
			UNION ALL
			SELECT a.matchid, a.bettype, a.betteam
			FROM dbo.rmBettransm_bk a WITH (NOLOCK)
			WHERE a.refno = @refno AND a.winlostdate < @BalanceUpDay 


			INSERT INTO @bettrans (transid, refno)
			SELECT transid, refno
			FROM dbo.rmBettrans WITH (NOLOCK)
			WHERE bettype = 29
				AND combo = @combo
				AND statusID = @statusID
				AND winlostdate >= @yesterday
				AND (
					@isSimilar = 0
					OR 
					(winlostdate = @winlostdate AND @isSimilar = 1)
					)
				AND refno <> @refno

			INSERT INTO @result (transid, cnt)
			SELECT b.transid, COUNT(1)
			FROM @bettrans b
				CROSS APPLY (
					SELECT bm.matchid, bm.bettype, bm.betteam
					FROM bodb02.dbo.bettransm bm WITH (NOLOCK)
					WHERE bm.refno = b.refno AND (bm.winlostdate IS NULL OR bm.winlostdate > @MoveBetsDay)
					UNION ALL
					SELECT bm.matchid, bm.bettype, bm.betteam
					FROM bodb02.dbo.bettransm14 bm WITH (NOLOCK)
					WHERE bm.refno = b.refno AND bm.winlostdate BETWEEN @BalanceUpDay AND @MoveBetsDay
					UNION ALL
					SELECT a.matchid, a.bettype, a.betteam
					FROM dbo.rmBettransm_bk a WITH (NOLOCK)
					WHERE a.refno = b.refno AND a.winlostdate < @BalanceUpDay 

				) r
				INNER JOIN @Selection s ON r.matchid = s.matchid AND r.bettype = s.bettype AND r.betteam = s.betteam
			GROUP BY b.transid
			HAVING COUNT(1) >= @filter


			SELECT @cnt_bets = @@ROWCOUNT
			SELECT  @NumberWon = COUNT(1) FROM bodb02.dbo.bettransm WITH (NOLOCK) WHERE refno = @refno AND statusID = 112 AND winlostdate > @MoveBetsDay
			SELECT  @NumberWon = @NumberWon + COUNT(1) FROM bodb02.dbo.bettransm14 WITH (NOLOCK) WHERE refno = @refno AND statusID = 112 AND winlostdate BETWEEN @BalanceUpDay AND @MoveBetsDay
			SELECT  @NumberWon = @NumberWon + COUNT(1) FROM dbo.rmBettransm_bk WITH (NOLOCK) WHERE refno = @refno AND statusID = 112 AND winlostdate < @BalanceUpDay 
		END
	
		IF @statusID = 112
		BEGIN
			
			INSERT INTO @Selection (matchid, bettype, betteam)
			SELECT a.matchid, a.bettype, a.betteam
			FROM bodb02.dbo.bettransm a WITH (NOLOCK)
			WHERE a.refno = @refno AND a.winlostdate > @MoveBetsDay
			UNION ALL
			SELECT a.matchid, a.bettype, a.betteam
			FROM bodb02.dbo.bettransm14 a WITH (NOLOCK)
			WHERE a.refno = @refno AND a.winlostdate BETWEEN @BalanceUpDay AND @MoveBetsDay
			UNION ALL
			SELECT a.matchid, a.bettype, a.betteam
			FROM dbo.rmBettransm_bk a WITH (NOLOCK)
			WHERE a.refno = @refno AND a.winlostdate < @BalanceUpDay 


			INSERT INTO @bettrans (transid, refno)
			SELECT transid, refno
			FROM dbo.rmBettrans WITH (NOLOCK)
			WHERE bettype = 29
				AND combo = @combo
				AND statusID = @statusID
				AND refno <> @refno
				AND winlostdate > @MoveBetsDay
				AND (
					(winlostdate = @winlostdate  AND @isSimilar = 1) OR (@isSimilar = 0)
					)
			UNION 
			SELECT transid, refno
			FROM dbo.rmBettrans_Old WITH (NOLOCK)
			WHERE bettype = 29
				AND combo = @combo
				AND statusID = @statusID
				AND refno <> @refno
				AND winlostdate BETWEEN @BalanceUpDay AND  @MoveBetsDay
				AND (
				(winlostdate = @winlostdate  AND @isSimilar = 1) OR (@isSimilar = 0)
				)

			INSERT INTO @result (transid, cnt)
			SELECT b.transid, COUNT(1)
			FROM @bettrans b
				CROSS APPLY (
					SELECT bm.matchid, bm.bettype, bm.betteam
					FROM bodb02.dbo.bettransm bm WITH (NOLOCK)
					WHERE bm.refno = b.refno AND bm.winlostdate > @MoveBetsDay
					UNION ALL
					SELECT bm.matchid, bm.bettype, bm.betteam
					FROM bodb02.dbo.bettransm14 bm WITH (NOLOCK)
					WHERE bm.refno = b.refno AND bm.winlostdate BETWEEN @BalanceUpDay AND @MoveBetsDay
					UNION ALL
					SELECT a.matchid, a.bettype, a.betteam
					FROM dbo.rmBettransm_bk a WITH (NOLOCK)
					WHERE a.refno = b.refno AND a.winlostdate < @BalanceUpDay 

				) r
				INNER JOIN @Selection s ON r.matchid = s.matchid AND r.bettype = s.bettype AND r.betteam = s.betteam
			GROUP BY b.transid
			HAVING COUNT(1) >= @filter

			SELECT @cnt_bets = @@ROWCOUNT
			SELECT  @NumberWon = COUNT(1) FROM bodb02.dbo.bettransm WITH (NOLOCK) WHERE refno = @refno AND statusID = 112 AND winlostdate > @MoveBetsDay
			SELECT  @NumberWon = @NumberWon + COUNT(1) FROM bodb02.dbo.bettransm14 WITH (NOLOCK) WHERE refno = @refno AND statusID = 112 AND winlostdate BETWEEN @BalanceUpDay AND @MoveBetsDay
			SELECT  @NumberWon = @NumberWon + COUNT(1) FROM dbo.rmBettransm_bk WITH (NOLOCK) WHERE refno = @refno AND statusID = 112 AND winlostdate < @BalanceUpDay 
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
		HAVING COUNT(1) >= @filter

		
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
				>= @filter
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
			,CASE WHEN s.isDeposit = 0 OR s.site IN ('Saba789','NovaCasino','SEAL888') THEN 'C' ELSE 'L' END SiteGroup
			,p.username
			,p.custid
			,p.bettype
			,ISNULL(r.level, 0) AS level
			,CASE WHEN p.transid2 NOT IN (-1,-3,1,2,3,4,5,6,7,8,9,11,43,44,-4,-5,50) THEN -2 ELSE p.transid2 END AS Sporttype
			,p.odds2 * p.TotalBet AS odds
			,(p.stake * p.actualrate) AS stake
			,(p.stake * (p.odds2 - 1) * p.actualrate * (1 - p.tpositiontaking)) AS net_win
			,p.hdp2		AS TotalSelection
			,ISNULL(@NumberWon, 0)	AS NumberWon
			,p.TotalBet	AS TotalBet
			,@cnt_bets	AS cnt_bets
			,CAST(CASE WHEN p.bettype = 29 AND p.betteam = N'1' AND p.oddsspread = 1 THEN 1 ELSE 0 END AS BIT) AS IsGOF
			,CAST(CASE WHEN p.bettype = 29 AND p.betteam = N'1' 
					AND ISNULL(TRY_CAST(TRY_CAST(p.ExtraInfo AS XML).value('(/p1/@bac)[1]', 'VARCHAR(50)') AS INT),0)|16 = ISNULL(TRY_CAST(TRY_CAST(p.ExtraInfo AS XML).value('(/p1/@bac)[1]', 'VARCHAR(50)') AS INT),0) 
					THEN 1 ELSE 0 END AS BIT) AS IsParlayGenerator
			,CAST(CASE WHEN p.bettype = 29 AND p.betteam = N'1' AND p.oddsspread = 2 THEN 1 ELSE 0 END AS BIT) AS IsBoostBonus
			,p.statusID as statusID
			,(p.odds2 - 1) * p.stake * p.actualrate AS potentialWinningAmt
			,ci.CustomerClass
			,l.username AS TrackingUser
		FROM dbo.rmBettrans p WITH (NOLOCK) 
			INNER JOIN bodb02.dbo.CustInfo ci WITH(NOLOCK) ON p.custid = ci.custid
			LEFT JOIN rmCustomer r WITH (NOLOCK) ON p.custid = r.custid
			LEFT JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON p.custid = c.custid
			LEFT JOIN bodb02.dbo.site s WITH(NOLOCK) ON c.site = s.site
			LEFT JOIN dbo.rmUserTrackingLog l WITH(NOLOCK) ON p.transid = l.transid
		WHERE p.transid = @transid

		SELECT
			p.transid
			,p.refno
			,CASE WHEN s.isDeposit = 0 OR s.site IN ('Saba789','NovaCasino','SEAL888') THEN 'C' ELSE 'L' END SiteGroup
			,p.username
			,p.custid
			,ISNULL(rc.level, 0) AS level
			,CASE WHEN @statusID = 0  THEN stake * (odds2 - 1) * actualrate * (1 - p.tpositiontaking) ELSE ((p.winlost - p.actual_stake) * p.actualrate) END  AS net_win
			,cnt AS similar_selection
			,(p.stake * p.actualrate) AS stake
			,ci.CustomerClass
			,(p.odds2 - 1) * p.stake * p.actualrate AS potentialWinningAmt
			, p.ip IP
			,l.username AS TrackingUser
		FROM @result r
			INNER JOIN dbo.rmBettrans p WITH (NOLOCK) ON r.transid = p.transid
			INNER JOIN bodb02.dbo.CustInfo ci WITH(NOLOCK) ON p.custid = ci.custid
			LEFT JOIN rmCustomer rc WITH (NOLOCK) ON p.custid = rc.custid
			LEFT JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON p.custid = c.custid
			LEFT JOIN bodb02.dbo.site s WITH(NOLOCK) ON c.site = s.site
			LEFT JOIN dbo.rmUserTrackingLog l WITH(NOLOCK) ON p.transid = l.transid
		ORDER BY cnt DESC
	END

	IF @statusID = 112
	BEGIN
		SELECT
			p.transdate
			,p.transid
			,p.refno
			,CASE WHEN s.isDeposit = 0 OR s.site IN ('Saba789','NovaCasino','SEAL888') THEN 'C' ELSE 'L' END SiteGroup
			,p.username
			,p.custid
			,p.bettype
			,ISNULL(rc.level, 0) AS level
			,CASE WHEN p.transid2 NOT IN (-1,-3,1,2,3,4,5,6,7,8,9,11,43,44,-4,-5,50) THEN -2 ELSE p.transid2 END AS Sporttype
			,(p.winlost - p.actual_stake) / p.stake AS odds
			,(p.stake * p.actualrate) AS stake
			,((p.winlost - p.actual_stake) * p.actualrate) net_win
			,p.hdp2		AS TotalSelection
			,ISNULL(@NumberWon, 0)	AS NumberWon
			,p.TotalBet	AS TotalBet
			,@cnt_bets	AS cnt_bets
			,CAST(CASE WHEN p.bettype = 29 AND p.betteam = N'1' AND p.oddsspread = 1 THEN 1 ELSE 0 END AS BIT) AS IsGOF
			,CAST(CASE WHEN p.bettype = 29 AND p.betteam = N'1' 
					AND ISNULL(TRY_CAST(TRY_CAST(p.ExtraInfo AS XML).value('(/p1/@bac)[1]', 'VARCHAR(50)') AS INT),0)|16 = ISNULL(TRY_CAST(TRY_CAST(p.ExtraInfo AS XML).value('(/p1/@bac)[1]', 'VARCHAR(50)') AS INT),0) 
					THEN 1 ELSE 0 END AS BIT) AS IsParlayGenerator
			,CAST(CASE WHEN p.bettype = 29 AND p.betteam = N'1' AND p.oddsspread = 2 THEN 1 ELSE 0 END AS BIT) AS IsBoostBonus
			,p.statusID as statusID
			,((winlost - actual_stake) * (1 - p.tpositiontaking - CONVERT(DECIMAL(9, 8), ISNULL(p.epositiontaking, 0))) + scomm - CASE WHEN tpositiontaking = 1 THEN 0 ELSE scomm * CONVERT(DECIMAL(9, 8), ISNULL(p.epositiontaking, 0)) / (1 - tpositiontaking) END) * actualrate  AS houseLoseAmt
			,ci.CustomerClass
			,l.username AS TrackingUser
		FROM dbo.rmBettrans p WITH (NOLOCK) 
			INNER JOIN bodb02.dbo.CustInfo ci WITH(NOLOCK) ON p.custid = ci.custid
			LEFT JOIN rmCustomer rc WITH (NOLOCK) ON p.custid = rc.custid
			LEFT JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON p.custid = c.custid
			LEFT JOIN bodb02.dbo.site s WITH(NOLOCK) ON c.site = s.site
			LEFT JOIN dbo.rmUserTrackingLog l WITH(NOLOCK) ON p.transid = l.transid
		WHERE p.transid = @transid

		UNION 

		SELECT
			p.transdate
			,p.transid
			,p.refno
			,CASE WHEN s.isDeposit = 0 OR s.site IN ('Saba789','NovaCasino','SEAL888') THEN 'C' ELSE 'L' END SiteGroup
			,p.username
			,p.custid
			,p.bettype
			,ISNULL(rc.level, 0) AS level
			,CASE WHEN p.transid2 NOT IN (-1,-3,1,2,3,4,5,6,7,8,9,11,43,44,-4,-5,50) THEN -2 ELSE p.transid2 END AS Sporttype
			,(p.winlost - p.actual_stake) / p.stake AS odds
			,(p.stake * p.actualrate) AS stake
			,((p.winlost - p.actual_stake) * p.actualrate) net_win
			,p.hdp2		AS TotalSelection
			,ISNULL(@NumberWon, 0)	AS NumberWon
			,p.TotalBet	AS TotalBet
			,@cnt_bets	AS cnt_bets
			,CAST(CASE WHEN p.bettype = 29 AND p.betteam= N'1' AND p.oddsspread = 1 THEN 1 ELSE 0 END AS BIT) AS IsGOF
			,CAST(CASE WHEN p.bettype = 29 AND p.betteam= N'1' 
					AND ISNULL(TRY_CAST(TRY_CAST(p.ExtraInfo AS XML).value('(/p1/@bac)[1]', 'VARCHAR(50)') AS INT),0)|16 = ISNULL(TRY_CAST(TRY_CAST(p.ExtraInfo AS XML).value('(/p1/@bac)[1]', 'VARCHAR(50)') AS INT),0) 
					THEN 1 ELSE 0 END AS BIT) AS IsParlayGenerator
			,CAST(CASE WHEN p.bettype = 29 AND p.betteam= N'1' AND p.oddsspread = 2 THEN 1 ELSE 0 END AS BIT) AS IsBoostBonus
			,p.statusID as statusID
			,((winlost - actual_stake) * (1 - p.tpositiontaking - CONVERT(DECIMAL(9, 8), ISNULL(p.epositiontaking, 0))) + scomm - CASE WHEN tpositiontaking = 1 THEN 0 ELSE scomm * CONVERT(DECIMAL(9, 8), ISNULL(p.epositiontaking, 0)) / (1 - tpositiontaking) END) * actualrate  AS houseLoseAmt
			,ci.CustomerClass
			,l.username AS TrackingUser
		FROM dbo.rmBettrans_Old p WITH (NOLOCK) 
			INNER JOIN bodb02.dbo.CustInfo ci WITH(NOLOCK) ON p.custid = ci.custid
			LEFT JOIN rmCustomer rc WITH (NOLOCK) ON p.custid = rc.custid
			LEFT JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON p.custid = c.custid
			LEFT JOIN bodb02.dbo.site s WITH(NOLOCK) ON c.site = s.site
			LEFT JOIN dbo.rmUserTrackingLog l WITH(NOLOCK) ON p.transid = l.transid
		WHERE p.transid = @transid

		SELECT
			p.transid
			,p.refno
			,CASE WHEN s.isDeposit = 0 OR s.site IN ('Saba789','NovaCasino','SEAL888') THEN 'C' ELSE 'L' END SiteGroup
			,p.username
			,p.custid
			,ISNULL(rc.level, 0) AS level
			,CASE WHEN @statusID = 0  THEN stake * (odds2 - 1) * actualrate * (1 - p.tpositiontaking) ELSE ((p.winlost - p.actual_stake) * p.actualrate) END  AS net_win
			,cnt AS similar_selection
			,(p.stake * p.actualrate) AS stake
			,((winlost - actual_stake) * (1 - p.tpositiontaking - CONVERT(DECIMAL(9, 8), ISNULL(p.epositiontaking, 0))) + scomm - CASE WHEN tpositiontaking = 1 THEN 0 ELSE scomm * CONVERT(DECIMAL(9, 8), ISNULL(p.epositiontaking, 0)) / (1 - tpositiontaking) END) * actualrate AS houseLoseAmt
			,ci.CustomerClass
			,p.ip IP
			,l.username AS TrackingUser
		FROM @result r
			INNER JOIN dbo.rmBettrans p WITH (NOLOCK) ON r.transid = p.transid
			INNER JOIN bodb02.dbo.CustInfo ci WITH(NOLOCK) ON p.custid = ci.custid
			LEFT JOIN rmCustomer rc WITH (NOLOCK) ON p.custid = rc.custid
			LEFT JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON p.custid = c.custid
			LEFT JOIN bodb02.dbo.site s WITH(NOLOCK) ON c.site = s.site
			LEFT JOIN dbo.rmUserTrackingLog l WITH(NOLOCK) ON p.transid = l.transid
		WHERE p.winlostdate > @MoveBetsDay
		UNION 
		SELECT
			p.transid
			,p.refno
			,CASE WHEN s.isDeposit = 0 OR s.site IN ('Saba789','NovaCasino','SEAL888') THEN 'C' ELSE 'L' END SiteGroup
			,p.username
			,p.custid
			,ISNULL(rc.level, 0) AS level
			,CASE WHEN @statusID = 0  THEN stake * (odds2 - 1) * actualrate * (1 - p.tpositiontaking) ELSE ((p.winlost - p.actual_stake) * p.actualrate) END  AS net_win
			,cnt AS similar_selection
			,(p.stake * p.actualrate) AS stake
			,((winlost - actual_stake) * (1 - p.tpositiontaking - CONVERT(DECIMAL(9, 8), ISNULL(p.epositiontaking, 0))) + scomm - CASE WHEN tpositiontaking = 1 THEN 0 ELSE scomm * CONVERT(DECIMAL(9, 8), ISNULL(p.epositiontaking, 0)) / (1 - tpositiontaking) END) * actualrate AS houseLoseAmt
			,ci.CustomerClass
			,p.ip IP
			,l.username AS TrackingUser
		FROM @result r
			INNER JOIN dbo.rmBettrans_Old p WITH (NOLOCK) ON r.transid = p.transid
			INNER JOIN bodb02.dbo.CustInfo ci WITH(NOLOCK) ON p.custid = ci.custid
			LEFT JOIN rmCustomer rc WITH (NOLOCK) ON p.custid = rc.custid
			LEFT JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON p.custid = c.custid
			LEFT JOIN bodb02.dbo.site s WITH(NOLOCK) ON c.site = s.site
			LEFT JOIN dbo.rmUserTrackingLog l WITH(NOLOCK) ON p.transid = l.transid
		WHERE p.winlostdate BETWEEN @BalanceUpDay AND  @MoveBetsDay
		ORDER BY cnt DESC
	END

END
GO