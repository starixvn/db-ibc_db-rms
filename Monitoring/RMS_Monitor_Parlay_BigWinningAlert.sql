/*<info serverAlias="DBRMS-bodb_RMS" executers="bodbRMSNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[RMS_Monitor_Parlay_BigWinningAlert]

AS

/*
	Created: 20230404@Cherry
	DB: DBRMS-bodb_RMS
	Task: Parlay RMS - Get parlay tickets which big winning for letstalk

	Revisions:
		- 20230404@Cherry: Initialize SP [RedmineID: #186037]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @MBU TABLE (BalanceUpDay SMALLDATETIME, MoveBetsDay SMALLDATETIME)
	INSERT INTO @MBU (BalanceUpDay, MoveBetsDay)
	EXEC bodb02.dbo.Age_SelBalanceUpDay

	DECLARE @BalanceUpDay SMALLDATETIME, @MoveBetsDay SMALLDATETIME
	SELECT  @BalanceUpDay = BalanceUpDay, @MoveBetsDay = MoveBetsDay FROM @MBU

	DECLARE @min_tstamp BINARY(8), @max_tstamp BINARY(8)

	SELECT  @min_tstamp = CONVERT(BINARY(8), CONVERT(BIGINT, ISNULL(VValue, 0)) + 1)
	FROM dbo.rmSettings WITH (ROWLOCK)
	WHERE VName = 'BigWinningAlert_LastTstamp'

	IF @min_tstamp IS NULL
		SELECT @min_tstamp = MIN(tstamp) FROM bodb02.dbo.bettrans WITH (NOLOCK) WHERE winlostdate > @MoveBetsDay

	SELECT  @max_tstamp = MAX(tstamp) FROM bodb02.dbo.bettrans WITH (NOLOCK)

	CREATE TABLE #tmpBigWinning
	(
		TransID BIGINT,
		CustID INT,
		Bettype INT,
		Betteam NVARCHAR(10),
		Matchid INT,
		Refno BIGINT,
		Combo INT,
		Winlostdate SMALLDATETIME,
		Betcheck NVARCHAR(50),
		CurrencyID TINYINT,
		Stake MONEY,
		Winloss MONEY
	)

	INSERT INTO #tmpBigWinning
	(
		TransID,
		CustID,
		Bettype,
		Betteam,
		Matchid,
		Refno,
		Combo,
		Winlostdate,
		Betcheck,
		CurrencyID,
		Stake,
		Winloss 
	)
	SELECT
		b.transId,
		b.custid,
		b.bettype,
		b.betteam,
		b.matchid,
		b.refno,
		b.hdp2,
		b.winlostdate,
		b.betcheck,
		b.currency,
		b.Stake,
		b.winlost - b.actual_stake
	FROM bodb02.dbo.bettrans b WITH (NOLOCK)
	WHERE b.tstamp between @min_tstamp and @max_tstamp
		AND b.bettype IN (29, 38)
		AND b.statusID = 112
		AND b.currency <> 20
		AND (b.winlost - b.actual_stake) * b.actualrate >= 65000
		AND b.srecommend IN (SELECT custid FROM bodb02.dbo.Dep_CustSuper WITH (NOLOCK) WHERE site <> 'Saba789')
		AND NOT EXISTS (SELECT 1 FROM dbo.rmLastTicketAlert t WITH (NOLOCK) WHERE b.transid = t.transid AND t.JobType = 4)	

	CREATE TABLE #tmpSimilar
	(
		TransID BIGINT,
		CustID INT
	)

	CREATE TABLE #Result
	(
		BigTransID BIGINT,
		BigCustID INT,
		BigLicensee VARCHAR(50),
		BigSystemID VARCHAR(50),
		BigMemberID VARCHAR(50),
		BigCustomerClass SMALLINT,
		BigParlayType VARCHAR(50),
		BigCurrencyID INT,
		BigTotalSelection INT,
		BigMemberStake MONEY,
		BigWinningAmount MONEY,
		SimilarTransID BIGINT,
		SimilarCustID INT,
		SimilarSystemID VARCHAR(50),
		SimilarMemberID VARCHAR(50),
		SimilarCustomerClass SMALLINT
	)

	DECLARE @transid BIGINT, @bettype INT, @betteam NVARCHAR(10), @matchid INT, @refno BIGINT, 
		@combo INT, @winlostdate SMALLDATETIME, @betcheck NVARCHAR(50), @custid INT, @currencyid INT,
		@stake MONEY, @winloss MONEY

	CREATE TABLE #tmpSelection (matchid INT, bettype INT, betteam NVARCHAR(10))
	CREATE TABLE #tmpbettrans (transid BIGINT, refno BIGINT, custid INT)
	CREATE TABLE #tmpOriginalSMP_Selection (transid BIGINT, SelectionType INT)
	CREATE TABLE #tmpSMP_Selection (transid BIGINT, SelectionType INT, custid INT)

	WHILE EXISTS (SELECT TOP 1 1 FROM #tmpBigWinning)
	BEGIN
		SELECT TOP 1 @transid = transid,
				@bettype = bettype, 
				@betteam = betteam, 
				@matchid = matchid, 
				@refno = refno, 
				@combo = Combo, 
				@winlostdate = winlostdate, 
				@betcheck = betcheck,
				@custid = CustID,
				@currencyid = CurrencyID,
				@stake = Stake,
				@winloss = Winloss
		FROM #tmpBigWinning

		IF @bettype = 29
		BEGIN
			INSERT INTO #tmpSelection (matchid, bettype, betteam)
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

			INSERT INTO #tmpbettrans (transid, refno, custid)
			SELECT transid, refno, custid
			FROM dbo.rmBettrans WITH (NOLOCK)
			WHERE bettype = 29
				AND combo = @combo
				AND statusID = 112
				AND currency <> 20
				AND refno <> @refno
				AND winlostdate = @winlostdate
				AND srecommend IN (SELECT custid FROM bodb02.dbo.Dep_CustSuper WITH (NOLOCK) WHERE site <> 'Saba789')

			INSERT INTO #tmpSimilar (Transid, CustID)
				SELECT b.transid, b.custid
				FROM #tmpbettrans b
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
					INNER JOIN #tmpSelection s ON r.matchid = s.matchid AND r.bettype = s.bettype AND r.betteam = s.betteam
				GROUP BY b.transid, b.custid
				HAVING COUNT(1) >= @combo
		END		

		IF @bettype = 38
		BEGIN
			INSERT INTO #tmpOriginalSMP_Selection (TransId, SelectionType)
			SELECT b.transid, a.SelectionType
			FROM dbo.rmBettrans b WITH (NOLOCK)
				INNER JOIN bodb02.dbo.SMP_MarketSelection a WITH (NOLOCK) ON b.betcheck = a.MarketId
			WHERE b.transid = @transid
			
			INSERT INTO #tmpSMP_Selection (TransId, SelectionType, Custid)
			SELECT b.transid, a.SelectionType, b.custid
			FROM dbo.rmBettrans b WITH (NOLOCK)
				INNER JOIN bodb02.dbo.SMP_MarketSelection a WITH (NOLOCK) ON b.betcheck = a.MarketId
			WHERE b.hdp2 = @combo 		
				AND statusid = 112
				AND a.matchid = @MatchId
				AND winlostdate >= CONVERT(DATE, DATEADD(DAY, -1, GETDATE()))
				AND b.transid <> @transid
				AND b.srecommend IN (SELECT custid FROM bodb02.dbo.Dep_CustSuper WITH (NOLOCK) WHERE site <> 'Saba789')

			INSERT INTO #tmpSimilar (transid, custid)
			SELECT s.transid, s.custid
			FROM #tmpOriginalSMP_Selection r
				INNER JOIN #tmpSMP_Selection s ON r.SelectionType = s.SelectionType
			GROUP BY s.transid, s.custid
			HAVING COUNT(1) >= @combo
		END

		IF EXISTS(SELECT TOP 1 1 FROM #tmpSimilar)
		BEGIN
			INSERT INTO #Result 
			(
				BigTransID,
				BigCustID,
				BigLicensee,
				BigSystemID,
				BigMemberID,
				BigCustomerClass,
				BigParlayType,
				BigCurrencyID,
				BigTotalSelection,
				BigMemberStake,
				BigWinningAmount,
				SimilarTransID,
				SimilarCustID,
				SimilarSystemID,
				SimilarMemberID,
				SimilarCustomerClass 
			)
			SELECT
				@transid,
				@custid,
				ab.[Site],
				cb.username,
				substring(cb.username2, LEN(ab.[Site])+1, LEN(cb.username2)-LEN(ab.[Site])),
				ci.CustomerClass,
				CASE WHEN @bettype = 29 AND @betteam = '1' THEN 'Mix Parlay'
					WHEN @bettype = 29 AND @betteam <> '1' THEN 'Combo Parlay'
					WHEN @bettype = 38 THEN 'Single Match Parlay'
				END,
				@currencyid,
				@combo,
				@stake,
				@winloss,
				s.Transid,
				s.CustID,
				cs.username,
				substring(cs.username2, LEN(sa.[Site])+1, LEN(cs.username2)-LEN(sa.[Site])), 
				si.CustomerClass
			FROM #tmpSimilar s 
				LEFT JOIN bodb02.dbo.Customer cb WITH(NOLOCK) ON cb.custid = @custid
				LEFT JOIN bodb02.dbo.custInfo ci WITH(NOLOCK) ON ci.custid = @custid
				LEFT JOIN bodb02.dbo.Customer ab WITH(NOLOCK) ON cb.recommend = ab.custid
				LEFT JOIN bodb02.dbo.Customer cs WITH(NOLOCK) ON cs.custid = s.CustID
				LEFT JOIN bodb02.dbo.custInfo si WITH(NOLOCK) ON si.custid = s.CustID
				LEFT JOIN bodb02.dbo.Customer sa WITH(NOLOCK) ON cs.recommend = sa.custid
		END

		IF NOT EXISTS(SELECT TOP 1 1 FROM #tmpSimilar)
		BEGIN
			INSERT INTO #Result 
			(
				BigTransID,
				BigCustID,
				BigLicensee,
				BigSystemID,
				BigMemberID,
				BigCustomerClass,
				BigParlayType,
				BigCurrencyID,
				BigTotalSelection,
				BigMemberStake,
				BigWinningAmount
			)
			SELECT
				@transid,
				@custid,
				ab.[Site],
				cb.username,
				substring(cb.username2, LEN(ab.[Site])+1, LEN(cb.username2)-LEN(ab.[Site])),
				ci.CustomerClass,
				CASE WHEN @bettype = 29 AND @betteam = '1' THEN 'Mix Parlay'
					WHEN @bettype = 29 AND @betteam <> '1' THEN 'Combo Parlay'
					WHEN @bettype = 38 THEN 'Single Match Parlay'
				END,
				@currencyid,
				@combo,
				@stake,
				@winloss
			FROM bodb02.dbo.Customer cb WITH(NOLOCK)
				LEFT JOIN bodb02.dbo.custInfo ci WITH(NOLOCK) ON ci.custid = @custid
				LEFT JOIN bodb02.dbo.Customer ab WITH(NOLOCK) ON cb.recommend = ab.custid
			WHERE cb.custid = @custid
		END

		DELETE FROM #tmpSimilar
		DELETE FROM #tmpbettrans
		DELETE FROM #tmpOriginalSMP_Selection
		DELETE FROM #tmpSMP_Selection
		DELETE FROM #tmpBigWinning WHERE TransID = @transid

	END

	SELECT BigLicensee,
			BigSystemID,
			BigMemberID,
			BigCustomerClass,
			BigTransID,
			BigParlayType,
			BigTotalSelection,
			e.currency BigCurrency,
			BigMemberStake,
			BigWinningAmount,
			SimilarSystemID,
			SimilarMemberID,
			SimilarCustomerClass,
			SimilarTransID
	FROM #Result d
		INNER JOIN bodb02.dbo.Exchange e WITH (NOLOCK) ON d.BigCurrencyID = e.exchangeid

	SELECT CONVERT(VARCHAR(200), CONVERT(BIGINT, @max_tstamp)) AS Tstamp

	DROP TABLE #Result
	DROP TABLE #tmpbettrans
	DROP TABLE #tmpBigWinning
	DROP TABLE #tmpOriginalSMP_Selection
	DROP TABLE #tmpSelection
	DROP TABLE #tmpSimilar
	DROP TABLE #tmpSMP_Selection
	
END
GO