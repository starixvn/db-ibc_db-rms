/*<info serverAlias="DBARC-bodb_Archive"></info>*/

/*
	Created: 20200512@Percy
	DB: DBARC-bodb_Archive
	Task: Initialize data for new table: rmBettrans_Old

	Step 2: Insert data into temp table
*/

USE bodb_Archive
GO

CREATE TABLE #rmBettrans_Old
(
	transid bigint NOT NULL,
	custid int NOT NULL,
	transdate datetime NOT NULL,
	oddsid int NOT NULL,
	hdp1 smallmoney NULL,
	hdp2 smallmoney NULL,
	odds smallmoney NULL,
	stake money NOT NULL,
	status nvarchar(10) NULL,
	winlost money NULL,
	awinlost money NULL,
	mwinlost money NULL,
	playercomm money NULL,
	comm money NULL,
	acomm money NULL,
	apositiontaking smallmoney NULL,
	mpositiontaking smallmoney NULL,
	tpositiontaking smallmoney NULL,
	playerdiscount decimal(9, 8) NULL,
	discount decimal(9, 8) NULL,
	adiscount decimal(9, 8) NULL,
	livehomescore smallint NULL,
	liveawayscore smallint NULL,
	liveindicator bit NULL,
	betteam nvarchar(10) NULL,
	creator int NOT NULL,
	refno bigint NOT NULL,
	comstatus nvarchar(20) NULL,
	winlostdate smalldatetime NULL,
	betfrom nvarchar(1) NULL,
	betcheck nvarchar(50) NULL,
	checktime datetime NULL,
	oddsspread smallmoney NULL,
	actualrate float NULL,
	matchid int NULL,
	recommend int NOT NULL,
	mrecommend int NOT NULL,
	ruben tinyint NULL,
	betid bigint NULL,
	statuswinlost tinyint NULL,
	modds smallmoney NULL,
	bettype smallint NULL,
	betdaqid bigint NULL,
	actual_stake money NULL,
	currency tinyint NULL,
	ip nvarchar(15) NULL,
	transdesc nvarchar(1000) NULL,
	sdiscount decimal(9, 8) NULL,
	scomm money NULL,
	spositiontaking smallmoney NULL,
	swinlost money NULL,
	srecommend int NOT NULL,
	Username nvarchar(50) NULL,
	CurrencyName nvarchar(50) NULL,
	virtualrate float NOT NULL,
	oddstype tinyint NULL,
	statusID tinyint NULL,
	currency2 tinyint NULL,
	balance money NULL,
	SecAcceptFlag bit NULL,
	transid2 bigint NULL,
	combo int NULL,
	odds2 money NULL,
	TotalBet int NULL,
	epositiontaking smallmoney NULL
)

CREATE TABLE #__tmpByBatch
(
	transid bigint NOT NULL,
	custid int NOT NULL,
	transdate datetime NOT NULL,
	oddsid int NOT NULL,
	hdp1 smallmoney NULL,
	hdp2 smallmoney NULL,
	odds smallmoney NULL,
	stake money NOT NULL,
	status nvarchar(10) NULL,
	winlost money NULL,
	awinlost money NULL,
	mwinlost money NULL,
	playercomm money NULL,
	comm money NULL,
	acomm money NULL,
	apositiontaking smallmoney NULL,
	mpositiontaking smallmoney NULL,
	tpositiontaking smallmoney NULL,
	playerdiscount decimal(9, 8) NULL,
	discount decimal(9, 8) NULL,
	adiscount decimal(9, 8) NULL,
	livehomescore smallint NULL,
	liveawayscore smallint NULL,
	liveindicator bit NULL,
	betteam nvarchar(10) NULL,
	creator int NOT NULL,
	refno bigint NOT NULL,
	comstatus nvarchar(20) NULL,
	winlostdate smalldatetime NULL,
	betfrom nvarchar(1) NULL,
	betcheck nvarchar(50) NULL,
	checktime datetime NULL,
	oddsspread smallmoney NULL,
	actualrate float NULL,
	matchid int NULL,
	recommend int NOT NULL,
	mrecommend int NOT NULL,
	ruben tinyint NULL,
	betid bigint NULL,
	statuswinlost tinyint NULL,
	modds smallmoney NULL,
	bettype smallint NULL,
	betdaqid bigint NULL,
	actual_stake money NULL,
	currency tinyint NULL,
	ip nvarchar(15) NULL,
	transdesc nvarchar(1000) NULL,
	sdiscount decimal(9, 8) NULL,
	scomm money NULL,
	spositiontaking smallmoney NULL,
	swinlost money NULL,
	srecommend int NOT NULL,
	Username nvarchar(50) NULL,
	CurrencyName nvarchar(50) NULL,
	virtualrate float NOT NULL,
	oddstype tinyint NULL,
	statusID tinyint NULL,
	currency2 tinyint NULL,
	balance money NULL,
	SecAcceptFlag bit NULL,
	transid2 bigint NULL,
	combo int NULL,
	odds2 money NULL,
	TotalBet int NULL,
	epositiontaking smallmoney NULL
)

CREATE INDEX IX_bettype ON #__tmpByBatch (bettype, refno) INCLUDE (transid, stake, betteam, hdp2)

DECLARE @fromdate SMALLDATETIME = '2020-02-01', @todate SMALLDATETIME, @isBreak BIT = 0
DECLARE @ErrMsg VARCHAR(2000) = ''

WHILE 1 = 1
BEGIN
	SET @ErrMsg = 'Current month = ' + CONVERT(VARCHAR(10), @fromdate, 120)
	RAISERROR (@ErrMsg, 1, 0) WITH NOWAIT

	SELECT @todate = DATEADD(DAY, -1, DATEADD(MONTH, DATEDIFF(MONTH, 0, @fromdate) + 1, 0))

	IF @todate >= '2020-05-15' -- Current BU Date
	BEGIN
		SET @todate = '2020-05-14'
		SET @isBreak = 1
	END

	TRUNCATE TABLE #rmBettrans_Old
	
	INSERT INTO #rmBettrans_Old
	(
		transid,custid,transdate,oddsid,hdp1,hdp2,odds,stake,status,winlost,awinlost,mwinlost,playercomm,comm,acomm
		,apositiontaking,mpositiontaking,tpositiontaking,playerdiscount,discount,adiscount,livehomescore,liveawayscore
		,liveindicator,betteam,creator,refno,comstatus,winlostdate,betfrom,betcheck,checktime,oddsspread,actualrate,matchid
		,recommend,mrecommend,ruben,betid,statuswinlost,modds,bettype,betdaqid,actual_stake,currency,ip,transdesc
		,sdiscount,scomm,spositiontaking,swinlost,srecommend,Username,CurrencyName,virtualrate,oddstype,statusID,currency2
		,balance,SecAcceptFlag,epositiontaking,transid2,combo,odds2,TotalBet
	)
	SELECT
		transid,custid,transdate,oddsid,hdp1,hdp2,odds,stake,status,winlost,awinlost,mwinlost,playercomm,comm,acomm
		,apositiontaking,mpositiontaking,tpositiontaking,playerdiscount,discount,adiscount,livehomescore,CASE WHEN bettype IN (38, 376) THEN 1 ELSE liveawayscore END
		,liveindicator,betteam,creator,refno,comstatus,winlostdate,betfrom,betcheck,checktime,oddsspread,actualrate,matchid
		,recommend,mrecommend,ruben,betid,statuswinlost,modds,bettype,betdaqid,actual_stake,currency,ip,transdesc
		,sdiscount,scomm,spositiontaking,swinlost,srecommend,Username,CurrencyName,virtualrate,oddstype,statusID,currency2
		,balance,SecAcceptFlag,epositiontaking,CASE WHEN bettype IN (38, 376) THEN 1 ELSE 0 END,hdp2,odds,1
	FROM dbo.bettrans_bk b WITH (NOLOCK)
		CROSS APPLY (
			SELECT TOP 1 c.username, e.currency AS CurrencyName
			FROM bodb02.dbo.Customer c WITH (NOLOCK)
				INNER JOIN bodb02.dbo.exchange e WITH (NOLOCK) ON c.currency = e.exchangeid
			WHERE b.custid = c.custid
		) c
	WHERE b.winlostdate BETWEEN @fromdate AND @todate
		AND bettype IN (29, 38, 376)

	WHILE 1=1
	BEGIN
		TRUNCATE TABLE #__rmBettrans_Old

		DELETE TOP (5000) FROM #rmBettrans_Old
		OUTPUT DELETED.*
		INTO #__tmpByBatch

		-- transid2 (sporttype)
		UPDATE b
		SET b.transid2 = s.sporttype
		FROM #__tmpByBatch b
			CROSS APPLY (
				SELECT CASE
							WHEN COUNT(DISTINCT sporttype) = 1 THEN MIN(sporttype)
							WHEN MIN(sporttype) = 1 THEN -3
							ELSE -1 END AS sporttype
				FROM
				(
					SELECT m.sporttype
					FROM bodb02.dbo.bettransm14 bm WITH (NOLOCK)
						INNER JOIN bodb02.dbo.match14 m WITH (NOLOCK) ON bm.matchid = m.matchid
					WHERE bm.refno = b.refno

					UNION ALL
					SELECT m.sporttype
					FROM dbo.bettransm bm WITH (NOLOCK)
						INNER JOIN dbo.match_bk m WITH (NOLOCK) ON bm.matchid = m.matchid
					WHERE bm.refno = b.refno
				) s
			) s
		WHERE b.bettype = 29
			AND b.transid2 = 0

		-- TotalBet
		UPDATE b
		SET b.TotalBet = t.TotalBet
		FROM #__tmpByBatch b
			CROSS APPLY (
				SELECT SUM(rcs.cnt) AS TotalBet
				FROM bodb02.dbo.RefCombinationSet rcs WITH (NOLOCK)
				WHERE rcs.N = b.hdp2
					AND (b.betteam & rcs.bitmapR) > 0
			) t
		WHERE b.bettype = 29

		-- odds2
		CREATE TABLE #tmp (transid BIGINT, stake MONEY, N TINYINT, bitmapR INT, odds SMALLMONEY, SetStake MONEY, RN TINYINT)
		CREATE CLUSTERED INDEX CIX_transid ON #tmp (transid)

		INSERT INTO #tmp (transid, stake, N, bitmapR, odds, SetStake, RN)
		SELECT b.transid, b.stake, b.hdp2, b.betteam, bm.odds, bm.stake AS SetStake
			,ROW_NUMBER() OVER(PARTITION BY b.transid ORDER BY bm.matchid) AS RN
		FROM #__tmpByBatch b
			CROSS APPLY (
				SELECT bm.odds, bm.stake, bm.matchid
				FROM bodb02.dbo.bettransm14 bm WITH (NOLOCK)
				WHERE bm.refno = b.refno
					
				UNION ALL
				SELECT bm.odds, bm.stake, bm.matchid
				FROM dbo.bettransm bm WITH (NOLOCK)
				WHERE bm.refno = b.refno
			) bm
		WHERE b.bettype = 29

		;WITH CTE_ParlayStake AS
		(
			SELECT transid, RN, SetStake FROM #tmp
		)
		,CTE_odds AS
		(
			SELECT transid, CASE WHEN stake = 0 THEN 0 ELSE SUM(odds * SetStake) / stake END AS odds2
			FROM (
				SELECT t.transid, t.stake, ps.SetStake, EXP(SUM(LOG(t.odds))) AS odds
				FROM #tmp t
					INNER JOIN bodb02.dbo.RefCombinationSet rcs WITH (NOLOCK) ON t.N = rcs.N AND (t.bitmapR & rcs.bitmapR) > 0
					INNER JOIN bodb02.dbo.RefCombination rc WITH (NOLOCK) ON rcs.N = rc.N AND rcs.R = rc.R AND t.RN = rc.Seq
					INNER JOIN CTE_ParlayStake ps ON t.transid = ps.transid AND rc.R = ps.RN
				GROUP BY t.transid, t.stake, ps.SetStake, rc.Serial
			) r
			GROUP BY transid, stake
		)
		UPDATE b
		SET b.odds2 = o.odds2
		FROM #__tmpByBatch b
			INNER JOIN CTE_odds o ON b.transid = o.transid
		WHERE b.bettype = 29

		DROP TABLE #tmp

		INSERT INTO dbo.rmBettrans_Old_Test
		(
			transid,custid,transdate,oddsid,hdp1,hdp2,odds,stake,status,winlost,awinlost,mwinlost,playercomm,comm,acomm
			,apositiontaking,mpositiontaking,tpositiontaking,playerdiscount,discount,adiscount,livehomescore,liveawayscore
			,liveindicator,betteam,creator,refno,comstatus,winlostdate,betfrom,betcheck,checktime,oddsspread,actualrate,matchid
			,recommend,mrecommend,ruben,betid,statuswinlost,modds,bettype,betdaqid,actual_stake,currency,ip,transdesc
			,sdiscount,scomm,spositiontaking,swinlost,srecommend,Username,CurrencyName,virtualrate,oddstype,statusID,currency2
			,balance,SecAcceptFlag,epositiontaking,transid2,combo,odds2,TotalBet
		)
		SELECT
			transid,custid,transdate,oddsid,hdp1,hdp2,odds,stake,status,winlost,awinlost,mwinlost,playercomm,comm,acomm
			,apositiontaking,mpositiontaking,tpositiontaking,playerdiscount,discount,adiscount,livehomescore,CASE WHEN bettype IN (38, 376) THEN 1 ELSE liveawayscore END
			,liveindicator,betteam,creator,refno,comstatus,winlostdate,betfrom,betcheck,checktime,oddsspread,actualrate,matchid
			,recommend,mrecommend,ruben,betid,statuswinlost,modds,bettype,betdaqid,actual_stake,currency,ip,transdesc
			,sdiscount,scomm,spositiontaking,swinlost,srecommend,Username,CurrencyName,virtualrate,oddstype,statusID,currency2
			,balance,SecAcceptFlag,epositiontaking,1,hdp2,odds,1
		FROM #__tmpByBatch

		IF @@ROWCOUNT < 5000
			BREAK
	END

	SELECT @fromdate = DATEADD(MONTH, 1, @fromdate)

	IF @isBreak = 1
		BREAK
END

DROP TABLE #rmBettrans_Old
DROP TABLE #__tmpByBatch