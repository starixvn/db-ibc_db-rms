/*<info serverAlias="DBRMS-bodb_RMS" executers="bodbRMSNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE dbo.[RMS_Monitor_Parlay_LastTicketAlert]
	@IsTest              BIT   = 0, 
	@MinPotentialWinning MONEY = 50000
AS

/*
	Created: Franklin
	Date: 2020-02-26
	DB: DBRMS/bodb_RMS
	Task: Notify/Alert by Winning Amount

	Revisions:
		- 20200226@Franklin: Notify/Alert by Winning Amount #129275
		- 20200703@Percy: Add jobtype to support many jobs [RedmineID: #137010]
		- 20210414@Danny: Notify/Alert for ticket have half-lose selection [RedmineID: #137010]
*/

BEGIN
     SET NOCOUNT ON;

     DECLARE @BetType INT;
     SELECT @BetType = 29;

     -- #sumtotal

     CREATE TABLE #sumtotal
     (transid           BIGINT, 
      refno             BIGINT, 
      custid            INT, 
      username          NVARCHAR(50), 
      currencyname      VARCHAR(50), 
      winningamount     MONEY, 
      companyloseamount MONEY, 
      totalselection    INT, 
      odds              MONEY, 
      housept           MONEY, 
      betteam           NVARCHAR(10), 
      numberlose        INT DEFAULT(0), 
      numberrunning     INT DEFAULT(0)
     );
     INSERT INTO #sumtotal
     (transid, 
      refno, 
      custid, 
      username, 
      currencyname, 
      winningamount, 
      companyloseamount, 
      totalselection, 
      odds, 
      housept, 
      betteam
     )
            SELECT b.transid, 
                   b.refno, 
                   b.custid, 
                   b.username, 
                   b.CurrencyName AS currency, 
                   SUM((b.odds2 - 1) * b.stake * CASE
                                                     WHEN @IsTest = 1
                                                     THEN 1
                                                     ELSE b.actualrate
                                                 END) AS WinningAmount, 
                   SUM((b.odds2 - 1) * b.stake * CASE
                                                     WHEN @IsTest = 1
                                                     THEN 1
                                                     ELSE b.actualrate
                                                 END * (1 - b.tpositiontaking)) AS CompanyLoseAmount, 
                   b.hdp2 AS TotalSelections, 
                   AVG(b.odds2 * b.TotalBet) AS Odds, 
                   AVG(1 - b.tpositiontaking) AS HousePT, 
                   b.betteam AS BetTeam
            FROM rmBettrans AS b WITH(NOLOCK)
            WHERE b.bettype = @BetType
                  AND b.statusid = 0
                  AND ((@IsTest = 1
                        AND currency = 20)
                       OR (@IsTest = 0
                           AND currency <> 20))
            GROUP BY b.transid, 
                     b.refno, 
                     b.custid, 
                     b.Username, 
                     b.CurrencyName, 
                     b.hdp2, 
                     b.betteam
            HAVING SUM((b.odds2 - 1) * b.stake * CASE
                                                     WHEN @IsTest = 1
                                                     THEN 1
                                                     ELSE b.actualrate
                                                 END) >= @MinPotentialWinning
            ORDER BY WinningAmount DESC;
     UPDATE s
       SET 
           numberlose =
     (
         SELECT COUNT(bm.transid)
         FROM bodb02.dbo.bettransm bm WITH(NOLOCK)
              INNER JOIN bodb02.dbo.match m WITH(NOLOCK) ON bm.matchid = m.matchid
         WHERE s.refno = bm.refno
               AND bm.statusid = 113 AND bm.statuswinlost = 4
     ), 
           numberrunning =
     (
         SELECT COUNT(bm.transid)
         FROM bodb02.dbo.bettransm bm WITH(NOLOCK)
              INNER JOIN bodb02.dbo.match m WITH(NOLOCK) ON bm.matchid = m.matchid
         WHERE s.refno = bm.refno
               AND bm.statusid = 0
     )
     FROM #sumtotal s;
     UPDATE s
       SET 
           numberlose = s.numberlose +
     (
         SELECT COUNT(bm.transid)
         FROM bodb02.dbo.bettransm14 bm WITH(NOLOCK)
              INNER JOIN bodb02.dbo.match14 m WITH(NOLOCK) ON bm.matchid = m.matchid
         WHERE s.refno = bm.refno
               AND bm.statusid = 113 AND bm.statuswinlost = 4
     ), 
           numberrunning = s.numberrunning +
     (
         SELECT COUNT(bm.transid)
         FROM bodb02.dbo.bettransm14 bm WITH(NOLOCK)
              INNER JOIN bodb02.dbo.match14 m WITH(NOLOCK) ON bm.matchid = m.matchid
         WHERE s.refno = bm.refno
               AND bm.statusid = 0
     )
     FROM #sumtotal s;
     CREATE TABLE #lastalert
     (transid     BIGINT, 
      alerttime   DATETIME, 
      alertamount MONEY
     );
     INSERT INTO #lastalert
     (transid, 
      alerttime, 
      alertamount
     )
            SELECT l.TransId, 
                   l.AlertTime, 
                   l.AlertAmount
            FROM rmLastTicketAlert l WITH(NOLOCK)
			WHERE ISNULL(JobType, 1) = 1;
     -- SELECT 
     SELECT CASE
                WHEN s.betteam = '1'
                THEN 'Mix Parlay'
                ELSE 'Combo Parlay'
            END AS ParlayType, 
            s.transid AS TransId, 
            s.username AS UserName, 
            s.currencyname AS CurrencyName, 
            s.winningamount AS WinningAmount, 
            s.companyloseamount AS CompanyLoseAmount, 
            s.totalselection AS TotalSelection, 
            s.odds AS Odds, 
            s.housept AS HousePt, 
            ISNULL(p.AlertAmount, 0) AS AlertAmount
     FROM #sumtotal s
          LEFT JOIN #lastalert p ON s.transid = p.transid
     WHERE s.numberlose = 0
           AND s.numberrunning = 1;
     DROP TABLE #sumtotal;
     DROP TABLE #lastalert;
END
GO