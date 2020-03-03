USE bodb_RMS
GO

/*
	Created: 20200302@Percy
	DB: DBRMS.bodb_RMS
	Task: Regen data for new column epositiontaking on rmBettrans
*/

CREATE TABLE #bettrans (transid BIGINT NOT NULL PRIMARY KEY, epositiontaking SMALLMONEY)
CREATE TABLE #tmpBettrans (transid BIGINT NOT NULL PRIMARY KEY, epositiontaking SMALLMONEY)

-- 5s
INSERT INTO #bettrans (transid, epositiontaking)
SELECT b.transid, b.epositiontaking
FROM bodb02.dbo.bettrans b WITH (NOLOCK)
	INNER JOIN dbo.rmBettrans rb WITH (NOLOCK) ON b.transid = rb.transid

WHILE 1=1
BEGIN
	TRUNCATE TABLE #tmpBettrans

	DELETE TOP (1000) #bettrans OUTPUT DELETED.transid, DELETED.epositiontaking INTO #tmpBettrans (transid, epositiontaking)

	IF @@ROWCOUNT = 0
		BREAK

	UPDATE rb WITH (ROWLOCK)
	SET rb.epositiontaking = t.epositiontaking
	FROM rmBettrans rb
		INNER JOIN #tmpBettrans t ON rb.transid = t.transid

	WAITFOR DELAY '00:00:00.280'
END

DROP TABLE #bettrans
DROP TABLE #tmpBettrans