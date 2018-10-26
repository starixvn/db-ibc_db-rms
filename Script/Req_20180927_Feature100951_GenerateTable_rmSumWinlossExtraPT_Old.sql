
/*
Created: Jacob
Date: 2018-09-27
Task: Apply Extra PT and Super Comm to Report.  RedmineID: #100951
DB: DBARC/bodb_Archive
		
Revisions:
    - 20180927@Jacob: Apply Extra PT and Super Comm to Report.  RedmineID: #100951 		
Parameter's Explanation:
*/

USE bodb_Archive
GO

SET NOCOUNT ON;
DECLARE @fromdate SMALLDATETIME;
DECLARE @todate SMALLDATETIME;

SELECT TOP 1 @todate = DATEADD(day, -1, winlostdate)
FROM bodb02.dbo.bettrans WITH (NOLOCK)
WHERE bettype = 20000
      AND matchid = 0
      AND custid = 3;

SELECT @fromdate = DATEADD(day, -366, @todate);


DECLARE @tempdate SMALLDATETIME;
SELECT @tempdate = @fromdate;


-- 1.0 Cache data for Acc_GroupExtraPTSetting

CREATE TABLE #ExtraPT_Sel( ProductID  INT,
                        Sporttype  INT,
                        SubProduct VARCHAR(100),
                        SuperID    INT,
				    FromDate DATETIME,
				    ToDate DATETIME,
                        ExtraPT    DECIMAL(9, 8));
INSERT INTO #ExtraPT_Sel
		  ( ProductID, Sporttype, SubProduct, SuperID, FromDate, ToDate, ExtraPT)
SELECT ProductID, SportType, SubProduct, SuperId, FromDate, ToDate, SUM(ExtraPT) AS ExtraPT
FROM bodb02.dbo.Acc_GroupExtraPTSetting AS a WITH (NOLOCK)
WHERE a.ProductID = 1
    AND a.Sporttype = 0
    AND a.SubProduct = ''
GROUP BY ProductID, SportType, SubProduct, SuperId, FromDate, ToDate;

CREATE TABLE #TemprmSumWinloss
                     ([winlostdate]     [SMALLDATETIME] NOT NULL,
                      [custid]          [INT] NOT NULL,
                      [sporttype]       [SMALLINT] NULL,
                      [statusid]        [TINYINT] NOT NULL,
                      [combo]           [TINYINT] NOT NULL,
					  [parlaytype]		[TINYINT] NULL,
                      [extraPT_scomm]   [MONEY] NULL,
                      [extraPT_stake]   [MONEY] NULL,
                      [extraPT_winlost] [MONEY] NULL,
                      [extraPT_comm]    [MONEY] NULL
                     );
CREATE TABLE #tmpbettrans
                (Transid         BIGINT NOT NULL PRIMARY KEY,
                [winlostdate]   [SMALLDATETIME] NOT NULL,
                [custid]        [INT] NOT NULL,
                [statusid]      [TINYINT] NOT NULL,
                [currency]      [TINYINT] NULL,
                [stake]         [MONEY] NULL,
                [winlost]       [MONEY] NULL,
                [scomm]         [MONEY] NULL,
                [srecommend]    [INT] NULL,
                bettype         SMALLINT NULL,
                tpositiontaking SMALLMONEY NULL,
                hdp2            SMALLMONEY NULL,
                betcheck        NVARCHAR(50) NULL,
                transid2        BIGINT NULL,
                modds           SMALLMONEY NULL,
                betteam         NVARCHAR(10) NULL,
                refno           BIGINT NOT NULL,
                matchId         INT NULL
                );
CREATE TABLE #tmpbettransm
                (refno     BIGINT NOT NULL,
                sporttype INT NULL
                );

DECLARE @Message VARCHAR(200) = ''

-- 2. Loop for each date
WHILE @tempdate <= @todate
BEGIN
    SET @Message = '@tempdate: ' + CONVERT(VARCHAR(50), @tempdate, 121) + ' CurrentDateTime: ' + CONVERT(VARCHAR(50), GETDATE(), 121)
	RAISERROR (@Message, 0, 1) WITH NOWAIT
        
	truncate table #tmpbettrans
	truncate table #tmpbettransm
	truncate table #TemprmSumWinloss

    INSERT INTO #tmpbettrans
            (Transid,
            [winlostdate],
            [custid],
            [statusid],
            [stake],
            [winlost],
            [scomm],
            [srecommend],
            bettype,
            tpositiontaking,
            hdp2,
            betcheck,
            modds,
            betteam,
            refno,
            matchId
            )
            SELECT Transid,
                    [winlostdate],
                    [custid],
                    [statusid],
                    [stake],
                    [winlost],
                    [scomm],
                    [srecommend],
                    bettype,
                    tpositiontaking,
                    hdp2,
                    betcheck,
                    modds,
                    betteam,
                    refno,
                    matchId
            FROM dbo.bettrans_bk b WITH (NOLOCK)
            WHERE b.winlostdate = @tempdate
                    AND matchid IN(9, 29)
            AND bettype IN(9, 29)
            AND b.statusid IN(111, 112, 113);
    PRINT 'Finish to insert into #tmpbettrans. Total rows = '+CONVERT(NVARCHAR(20), @@ROWCOUNT);
    INSERT INTO #tmpbettransm
            (refno,
            sporttype
            )
            SELECT a.refno,
                    m.sporttype
            FROM #tmpbettrans b(NOLOCK)
                INNER JOIN dbo.bettransm a WITH (NOLOCK, INDEX = ix_bettransm) ON a.refno = b.refno
                INNER JOIN dbo.match_bk m(NOLOCK) ON a.matchid = m.matchid
            WHERE m.sporttype <= 99;
    INSERT INTO #tmpbettransm
            (refno,
            sporttype
            )
            SELECT a.refno,
                    m.sporttype
            FROM #tmpbettrans b(NOLOCK)
                INNER JOIN bodb02.dbo.bettransm14 a(NOLOCK) ON a.refno = b.refno
                INNER JOIN bodb02.dbo.match14 m(NOLOCK) ON a.matchid = m.matchid
            WHERE m.sporttype <= 99;
    UPDATE bb
        SET
            bb.transid2 = aa.transid2
    FROM #tmpbettrans bb
            INNER JOIN
			(
			SELECT b.refno,
					CASE
						WHEN COUNT(DISTINCT(sporttype)) = 1
						THEN MIN(sporttype)
						WHEN COUNT(DISTINCT(sporttype)) <> 1
							AND MIN(sporttype) = 1
						THEN-3
						ELSE-1
					END AS transid2
			FROM #tmpbettransm b
			GROUP BY b.refno
			) aa ON aa.refno = bb.refno;
    INSERT INTO #TemprmSumWinloss
            (winlostdate,
            custid,
            sporttype,
            statusid,
            combo,
			parlaytype,
            extraPT_scomm,
            extraPT_stake,
            extraPT_winlost,
            extraPT_comm
            )
            SELECT winlostdate,
                    b.custid,
                    transid2,
                    statusid,
                    CASE
                        WHEN bettype = 9
                        THEN RIGHT(betcheck, LEN(betcheck) - 1)
                        WHEN bettype = 29
                            AND betcheck IS NULL
                        THEN LEN(betteam)
                        ELSE hdp2
                    END AS combo,
					CASE WHEN bettype=9 THEN 1 
					  WHEN bettype=29 AND betteam='1' THEN 2
					  ELSE 3 END AS ParlayType,
                    SUM(scomm),
                    SUM(stake * ISNULL(a.ExtraPT, 0)),
                    SUM(-(winlost - stake) * ISNULL(a.ExtraPT, 0)),
                    SUM(scomm * ISNULL(a.ExtraPT, 0) / (1 - tpositiontaking))
            FROM #tmpbettrans b
                LEFT JOIN #ExtraPT_Sel AS a WITH (NOLOCK) ON srecommend = a.SuperId AND winlostdate BETWEEN a.FromDate AND a.Todate
            GROUP BY winlostdate,
                    b.custid,
                    transid2,
                    statusid,
                    CASE
                        WHEN bettype = 9
                        THEN RIGHT(betcheck, LEN(betcheck) - 1)
                        WHEN bettype = 29
                                AND betcheck IS NULL
                        THEN LEN(betteam)
                        ELSE hdp2
                    END,
					CASE WHEN bettype=9 THEN 1 
					  WHEN bettype=29 AND betteam='1' THEN 2
					  ELSE 3 END;
    INSERT INTO DB052.bodb_RMS.dbo.rmSumWinlossExtraPT_Old
            (winlostdate,
            custid,
            sporttype,
            statusid,
            combo,
			parlaytype,
            stake,
            winlost,
            comm,
            scomm
            )
            SELECT winlostdate,
                    custid,
                    sporttype,
                    statusid,
                    combo,
					parlaytype,
                    extraPT_stake,
                    extraPT_winlost,
                    extraPT_comm,
                    extraPT_scomm
            FROM #TemprmSumWinloss;
       
    SELECT @tempdate = DATEADD(day, 1, @tempdate);
END;
DROP TABLE #ExtraPT_Sel;
GO


