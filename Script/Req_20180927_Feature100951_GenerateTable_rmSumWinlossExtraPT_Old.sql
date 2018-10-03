
/*
Created: Jacob
Date: 2018-09-27
Task: Apply Extra PT and Super Comm to Report.  RedmineID: #100951
DB: DBRMS/bodb_RMS
		
Revisions:
    - 20180927@Jacob: Apply Extra PT and Super Comm to Report.  RedmineID: #100951 		
Parameter's Explanation:
*/

SET NOCOUNT ON;
DECLARE @fromdate SMALLDATETIME;
DECLARE @todate SMALLDATETIME;
SELECT @fromdate = DATEADD(day, -366, CONVERT(DATE, GETDATE()));
SELECT TOP 1 @todate = DATEADD(day, -1, winlostdate)
FROM bodb02.dbo.bettrans WITH (NOLOCK)
WHERE bettype = 20000
      AND matchid = 0
      AND custid = 3;
PRINT 'Starting to generate data in from '+CONVERT(NVARCHAR(50), @fromdate)+' to '+CONVERT(NVARCHAR(50), @todate);
CREATE TABLE #TemprmSumWinloss
             ([winlostdate]     [SMALLDATETIME] NOT NULL,
              [custid]          [INT] NOT NULL,
              [sporttype]       [SMALLINT] NULL,
              [statusid]        [TINYINT] NOT NULL,
              [combo]           [TINYINT] NOT NULL,
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
CREATE NONCLUSTERED INDEX [IX_refno] ON [dbo].#tmpbettrans([refno] ASC) WITH(PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY];
CREATE TABLE #tmpbettransm
             (refno     BIGINT NOT NULL,
              sporttype INT NULL
             );
CREATE CLUSTERED INDEX [IX_refno] ON [dbo].#tmpbettransm([refno] ASC) WITH(PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY];
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
       FROM DBARC.bodb_Archive.dbo.bettrans_bk b WITH (NOLOCK)
       WHERE b.winlostdate BETWEEN @fromdate AND @todate
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
            INNER JOIN DBARC.bodb_Archive.dbo.bettransm a(NOLOCK) ON a.refno = b.refno
            INNER JOIN DBARC.bodb_Archive.dbo.match_bk m(NOLOCK) ON a.matchid = m.matchid
       WHERE m.sporttype <= 99;
INSERT INTO #tmpbettransm
       (refno,
        sporttype
       )
       SELECT a.refno,
              m.sporttype
       FROM #tmpbettrans b(NOLOCK)
            INNER JOIN bodb02.dbo.bettransm a(NOLOCK) ON a.refno = b.refno
            INNER JOIN bodb02.dbo.match m(NOLOCK) ON a.matchid = m.matchid
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
              SUM(scomm),
              SUM(stake * ISNULL(a.ExtraPT, 0)),
              SUM(-(winlost - stake) * ISNULL(a.ExtraPT, 0)),
              SUM(scomm * ISNULL(a.ExtraPT, 0) / (1 - tpositiontaking))
       FROM #tmpbettrans b
            LEFT JOIN bodb02.dbo.Acc_GroupExtraPTSetting AS a WITH (NOLOCK) ON srecommend = a.SuperId
                                                                               AND winlostdate BETWEEN a.FromDate AND a.Todate
                                                                               AND a.ProductID = 1
                                                                               AND a.Sporttype = 0
                                                                               AND a.SubProduct = ''
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
                END;
PRINT 'Starting truncate  rmSumWinlossExtraPT_Old';
TRUNCATE TABLE rmSumWinlossExtraPT_Old;
INSERT INTO rmSumWinlossExtraPT_Old
       (winlostdate,
        custid,
        sporttype,
        statusid,
        combo,
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
              extraPT_stake,
              extraPT_winlost,
              extraPT_comm,
              extraPT_scomm
       FROM #TemprmSumWinloss;
PRINT 'Finish to generate data in from '+CONVERT(NVARCHAR(50), @fromdate)+' to '+CONVERT(NVARCHAR(50), @todate)+'. Total rows = '+CONVERT(NVARCHAR(20), @@ROWCOUNT);
DROP TABLE #tmpbettrans;
DROP TABLE #TemprmSumWinloss;
DROP TABLE #tmpbettransm;
GO


