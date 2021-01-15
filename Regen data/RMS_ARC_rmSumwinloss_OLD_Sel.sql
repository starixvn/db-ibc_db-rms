/*<info serverAlias="DBARC-bodb_Archive" isFunction="0" isNested="1"></info>*/
ALTER PROCEDURE RMS_ARC_rmSumwinloss_OLD_Sel
	@winlostdate SMALLDATETIME
AS
/*
	Created: 20210115@Danny
	DB: DBARC.bodb_Archive
	Task: PRMS - PRMS - rmSumwinloss_OLD
	-- Regen data rmSumwinloss_OLD by Winlostdate 
	Revisions:
	- 20210115@Danny: Regen data rmSumwinloss_OLD by Winlostdate  [RedmineID: #145926]
*/
BEGIN
	CREATE TABLE #rmBettrans_Old
	(
			transid				bigint primary key
			,custid				int
			,transdate			datetime
			,oddsid				int
			,hdp1				smallmoney
			,hdp2				smallmoney
			,odds				smallmoney
			,stake				money
			,status				nvarchar(10)
			,winlost			money
			,awinlost			money
			,mwinlost			money
			,playercomm			money
			,comm				money
			,acomm				money
			,apositiontaking	smallmoney
			,mpositiontaking	smallmoney
			,tpositiontaking	smallmoney
			,playerdiscount		decimal(9,8)
			,discount			decimal(9,8)
			,adiscount			decimal(9,8)
			,livehomescore		smallint
			,liveawayscore		smallint
			,liveindicator		bit
			,betteam			nvarchar(10)
			,creator			int
			,refno				bigint
			,comstatus			nvarchar(20)
			,winlostdate		smalldatetime
			,betfrom			nvarchar(1)
			,betcheck			nvarchar(50)
			,checktime			datetime
			,oddsspread			smallmoney
			,actualrate			float
			,matchid			int
			,recommend			int
			,mrecommend			int
			,ruben				tinyint
			,betid				bigint
			,statuswinlost		tinyint
			,modds				smallmoney
			,bettype			smallint
			,betdaqid			bigint
			,actual_stake		money
			,currency			tinyint
			,ip					nvarchar(15)
			,transdesc			nvarchar(1000)
			,sdiscount			decimal(9,8)
			,scomm				money
			,spositiontaking	smallmoney
			,swinlost			money
			,srecommend			int
			,Username			nvarchar(50)
			,CurrencyName		nvarchar(50)
			,virtualrate		float
			,oddstype			tinyint
			,statusID			tinyint
			,currency2			tinyint
			,balance			money
			,SecAcceptFlag		bit
			,transid2			bigint
			,combo				int
			,odds2				money
			,TotalBet			int
			,epositiontaking	smallmoney
	)


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
	WHERE b.winlostdate = @winlostdate 
		AND bettype IN (29, 38, 376)

	CREATE  INDEX cix_#rmBettrans_Old_bettype ON #rmBettrans_Old(bettype)
	----------------------------------------------------------------------------------
	DECLARE @__winlostdate SMALLDATETIME
	SET @__winlostdate = @winlostdate

	
	SELECT b.refno, bm.bettype, bm.statusID, m.leagueid , bm.odds, bm.stake, m.sporttype, CASE WHEN  l.LeagueGroupID IN (42, 74) THEN 1 ELSE -1 END Saba, bm.matchid
	INTO #bettransm_BK
	FROM #rmBettrans_Old b WITH (NOLOCK)
		INNER JOIN dbo.bettransm bm WITH (NOLOCK, INDEX = IX_bettransm, FORCESEEK) ON b.refno = bm.refno
		INNER JOIN dbo.match_bk m WITH (NOLOCK) ON bm.matchid = m.matchid
		INNER JOIN bodb02.dbo.League l WITH(NOLOCK) ON m.leagueid = l.leagueid
	WHERE bm.winlostdate >= DATEADD(DAY, -21, @__winlostdate) and b.bettype = 29

	CREATE CLUSTERED INDEX cix_#bettransm_BK ON #bettransm_BK(refno)


	-------- virtual league detected
	SELECT bm.refno, CASE
			-------------------------------
			WHEN COUNT(DISTINCT sporttype) = 1 AND MIN(sporttype) NOT IN (1,2) THEN MIN(sporttype)
			------------------------------- 
			WHEN COUNT(DISTINCT sporttype) = 1 AND MIN(sporttype) = 1 AND SUM(DISTINCT Saba) = 0 THEN -3 
			WHEN COUNT(DISTINCT sporttype) = 1 AND MIN(sporttype) = 1 AND SUM(DISTINCT Saba) > 0 THEN -4
			WHEN COUNT(DISTINCT sporttype) = 1 AND MIN(sporttype) = 1 AND SUM(DISTINCT Saba) < 0 THEN  1
			------------------------------
			WHEN COUNT(DISTINCT sporttype) = 1 AND MIN(sporttype) = 2 AND SUM(DISTINCT Saba) = 0 THEN -1
			WHEN COUNT(DISTINCT sporttype) = 1 AND MIN(sporttype) = 2 AND SUM(DISTINCT Saba) > 0 THEN -5
			WHEN COUNT(DISTINCT sporttype) = 1 AND MIN(sporttype) = 2 AND SUM(DISTINCT Saba) < 0 THEN  2

			------------------------------
			WHEN COUNT(DISTINCT sporttype) <> 1 AND MIN(sporttype) = 1 THEN -3
			ELSE -1 END AS sporttype 
	INTO #bettransm_BK_saba
	FROM #bettransm_BK bm WITH (NOLOCK) 
	GROUP BY bm.refno

	CREATE CLUSTERED INDEX cix_#bettransm_BK_saba ON #bettransm_BK_saba(refno)
	----------------------------------------------------------------------------------------


	-- transid2 (sporttype)
	UPDATE b
	SET b.transid2 = s.sporttype
	FROM #rmBettrans_Old b
	INNER JOIN #bettransm_BK_saba s ON b.refno = s.refno
	WHERE b.bettype = 29 AND b.transid2 = 0

	-- TotalBet
	UPDATE b
	SET b.TotalBet = t.TotalBet
	FROM #rmBettrans_Old b
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
	FROM #rmBettrans_Old b WITH (NOLOCK) 
	INNER JOIN  #bettransm_BK bm WITH (NOLOCK)   ON bm.refno = b.refno
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
	FROM #rmBettrans_Old b
		INNER JOIN CTE_odds o ON b.transid = o.transid
	WHERE b.bettype = 29

	DROP TABLE #tmp

		SELECT
			b.winlostdate
			,b.custid
			,b.transid2 AS sporttype
			,b.statusID
			,CASE WHEN b.bettype = 29 AND b.betcheck IS NULL THEN LEN(b.betteam) ELSE b.hdp2 END AS combo
			,b.username
			,b.currency
			,SUM(b.stake) AS stake
			,SUM(b.winlost) AS winlost
			,SUM(b.stake * (1 - b.tpositiontaking)) AS company_stake
			,SUM(-(b.winlost - b.stake) * (1 - b.tpositiontaking)) AS company_winlost
			,b.actualrate
			,SUM(b.modds) AS odds
			,COUNT(1) AS betcount
			,b.recommend
			,CASE
				WHEN b.bettype = 29 AND b.betteam = N'1' THEN 2
				WHEN b.bettype = 29 AND b.betteam <> N'1' THEN 3
				WHEN b.bettype = 38 THEN 4
				WHEN b.bettype = 376 THEN 5
				ELSE 0 END AS ParlayType
			,SUM(b.scomm) AS scomm
			,SUM(b.scomm * CONVERT(DECIMAL(9,8), b.epositiontaking) / (1 - b.tpositiontaking)) AS Extra_comm
			,SUM(b.stake * CONVERT(DECIMAL(9,8), b.epositiontaking)) AS Extra_stake
			,SUM(-(b.winlost - b.stake) * CONVERT(DECIMAL(9,8), b.epositiontaking)) AS Extra_winlost,
			b.mrecommend,
			b.srecommend,
			SUM(awinlost) awinlost,
			SUM(mwinlost) mwinlost,
			SUM(swinlost) swinlost,
			SUM(actual_stake) actual_stake,
			SUM(playercomm) playercomm,
			SUM(comm) comm,
			SUM(acomm) acomm
		FROM #rmBettrans_old b WITH (NOLOCK)
		GROUP BY
			b.winlostdate
			,b.custid
			,b.transid2
			,b.statusID
			,CASE WHEN b.bettype = 29 AND b.betcheck IS NULL THEN LEN(b.betteam) ELSE b.hdp2 END
			,b.username
			,b.currency
			,b.actualrate
			,b.recommend
			,CASE
				WHEN b.bettype = 29 AND b.betteam = N'1' THEN 2
				WHEN b.bettype = 29 AND b.betteam <> N'1' THEN 3
				WHEN b.bettype = 38 THEN 4
				WHEN b.bettype = 376 THEN 5
				ELSE 0 END,
			b.mrecommend,b.srecommend

	DROP TABLE #bettransm_BK_saba
	DROP TABLE #bettransm_BK
	DROP TABLE #rmBettrans_Old
END
