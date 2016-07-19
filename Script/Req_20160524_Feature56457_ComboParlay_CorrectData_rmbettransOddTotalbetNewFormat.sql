 /*
	Created: Winnie
	Date: 2016-05-23
	Task: Correct data RMS
	DB: DBRMS/bodb_RMS
*/
USE bodb_RMS
GO

CREATE TABLE #tmpBettrans (transid BIGINT PRIMARY KEY)

INSERT INTO #tmpBettrans (transid)
SELECT	transid
FROM	dbo.rmBettrans
WHERE	matchid = 29
		AND bettype = 29
		AND betcheck IS NOT NULL
		AND Totalbet IS NULL
		
	;WITH tmpbettrans AS(
		SELECT b.hdp2 AS selection_cnt, CAST(b.betteam as int) AS bitmapR, bm.odds, bm.stake AS SetStake, bm.refno, b.transid
			,RN = ROW_NUMBER() OVER (PARTITION BY bm.refno ORDER BY bm.matchid) --RN
		FROM rmBettrans b WITH (NOLOCK) 
			INNER JOIN
					(	select refno, odds, stake, matchid
						from bodb02.dbo.bettransm WITH(NOLOCK)
						union all
						select refno, odds, stake, matchid
						from bodb02.dbo.bettransm14 WITH(NOLOCK)
					)bm ON bm.refno = b.refno
			INNER JOIN #tmpBettrans c ON b.transid=c.transid
	),
	ParlayStake AS (SELECT refno, RN, SetStake FROM tmpbettrans)
	SELECT EXP(SUM(LOG(odds))) AS Odds, b.transid, ps.SetStake
	INTO #tmp
	FROM tmpbettrans b 
		INNER JOIN bodb02.dbo.RefCombinationSet_xtest rcs WITH(NOLOCK) ON b.selection_cnt = rcs.N AND (b.bitmapR & rcs.bitmapR) > 0  
		INNER JOIN bodb02.dbo.RefCombination_xtest rc WITH(NOLOCK) ON rcs.N = rc.N AND rcs.R = rc.R AND b.RN = rc.seq
		INNER JOIN ParlayStake ps ON ps.refno = b.refno AND ps.RN = rc.R
	GROUP BY b.transid, ps.SetStake, serial


	;WITH tmp AS(
		SELECT b.transid AS transid , CASE WHEN b.stake = 0 THEN 0 ELSE SUM (r.odds * r.SetStake)/b.stake END AS Odds2
		FROM rmBettrans b WITH(NOLOCK)
			INNER JOIN #tmp r ON b.transid = r.transid 
		GROUP BY b.transid, b.stake, b.TotalBet
	)
	UPDATE b
	SET b.odds2 = t.Odds2
	FROM rmBettrans b	
		INNER JOIN tmp t ON b.transid = t.transid		

	
	;WITH ParlayTotalBet AS(
		SELECT b.TransID, SUM (rcs.cnt) AS TotalBet
		FROM rmBettrans b WITH(NOLOCK)
			INNER JOIN #tmpBettrans c ON b.transid=c.transid
			INNER JOIN bodb02.dbo.RefCombinationSet_xtest rcs WITH(NOLOCK) ON b.hdp2 = rcs.N
		WHERE b.bettype=29 AND (b.betteam & rcs.bitmapR) > 0
		GROUP BY b.transid
	)
	UPDATE b
	SET b.TotalBet = pt.TotalBet
	FROM rmBettrans b 
	INNER JOIN ParlayTotalBet pt ON b.TransID = pt.TransID
	WHERE b.bettype=29 

DROP TABLE #tmpBettrans
DROP TABLE #tmp
--
