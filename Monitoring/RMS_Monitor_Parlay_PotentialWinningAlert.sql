
/*<info serverAlias="DBRMS-bodb_RMS" executers="bodbRMSNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[RMS_Monitor_Parlay_PotentialWinningAlert] @IsTest              BIT            = 0, 
                                                                 @IsSMP       BIT            = 0, 
                                                                 @MinPotentialWinning MONEY  = 500000
AS

/*
	Created: Jacob
	Date: 2020-02-07
	Task: Notify/Alert by Winning Amount
	DB: DBRMS/bodb_RMS

Revisions:

- 20200207@Jacob: Notify/Alert by Winning Amount #128093
- 20230620@Cherry: Manage Alert (#189147)
*/

     SET NOCOUNT ON;
     DECLARE @MinTransID BIGINT;
     DECLARE @BetType INT;
     SELECT @BetType = CASE
                           WHEN @IsSMP = 1
                           THEN 38
                           ELSE 29
                       END;
     
     -- #sumtotal
     CREATE TABLE #sumtotal
     (custid             INT, 
      username           NVARCHAR(50), 
      currencyname       VARCHAR(50), 
	  TransList NVARCHAR(MAX), 
	  TotalMemberStake MONEY,
      WinningAmount      MONEY, 
      CompanyLoseAmount  MONEY, 
      totalbets          INT, 
      totalselectionsmin INT, 
      totalselectionsmax INT, 
      odds               MONEY, 
      housept            MONEY,
     );
     INSERT INTO #sumtotal
     (custid, 
      username, 
      currencyname, 
	  TransList,
	  TotalMemberStake,
      winningamount, 
      companyloseamount, 
      totalbets, 
      totalselectionsmin, 
      totalselectionsmax, 
      odds, 
      housept
     )
            SELECT b.custid, 
                   b.username, 
                   b.CurrencyName AS currency, 
				   STUFF((SELECT  ',' + CAST(t.transid  AS VARCHAR(30))
					FROM rmBettrans t WITH(NOLOCK)
					WHERE t.custid = b.custid
						  AND t.bettype = @BetType
						  AND t.statusid = 0
						  AND ((@IsTest = 1	AND t.currency = 20)
								OR (@IsTest = 0	AND t.currency <> 20))
					FOR XML PATH(''), TYPE
					).value('.', 'NVARCHAR(MAX)')  
					,1,1,'') TransList,
				   SUM(b.stake * CASE WHEN @IsTest = 1 THEN 1
                                      ELSE b.actualrate END) AS TotalMemberStake,
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
                   COUNT(1) AS TotalBets, 
                   MIN(b.hdp2) AS TotalSelectionsMin, 
                   MAX(b.hdp2) AS TotalSelectionsMax, 
                   AVG(b.odds2 * b.TotalBet) AS Odds, 
                   AVG(1 - b.tpositiontaking) AS HousePT
            FROM rmBettrans b WITH(NOLOCK)                 
            WHERE b.bettype = @BetType
                  AND b.statusid = 0
                  AND ((@IsTest = 1
                        AND currency = 20)
                       OR (@IsTest = 0
                           AND currency <> 20))
            GROUP BY b.custid, 
                     b.username, 
                     b.CurrencyName
            HAVING SUM((b.odds2 - 1) * b.stake * CASE
                                                     WHEN @IsTest = 1
                                                     THEN 1
                                                     ELSE b.actualrate
                                                 END) >= @MinPotentialWinning
            ORDER BY WinningAmount DESC;

     -- #lastalert
     CREATE TABLE #lastalert
     (custid      INT, 
      alerttime   DATETIME, 
      alertamount MONEY
     );
     INSERT INTO #lastalert
     (custid, 
      alerttime, 
      alertamount
     )
            SELECT m.CustId, 
                   m.alerttime, 
                   p.AlertAmount
            FROM
            (
                SELECT custid, 
                       MAX(alerttime) alerttime
                FROM rmPotentialWinningAlert WITH(NOLOCK)
                WHERE IsSMP = @IsSMP
                GROUP BY custid
            ) m
            INNER JOIN rmPotentialWinningAlert p WITH(NOLOCK) ON m.CustId = p.CustId
                                                                 AND m.alerttime = p.AlertTime
            WHERE p.IsSMP = @IsSMP;

     -- #sumtotalfromlastalert
     CREATE TABLE #sumtotalfromlastalert
     (custid        INT, 
      winningamount MONEY
     );
     INSERT INTO #sumtotalfromlastalert
     (custid, 
      winningamount
     )
            SELECT b.custid, 
                   SUM((b.odds2 - 1) * b.stake * CASE
                                                     WHEN @IsTest = 1
                                                     THEN 1
                                                     ELSE b.actualrate
                                                 END) AS WinningAmount
            FROM rmBettrans b WITH(NOLOCK)
                 INNER JOIN #lastalert l ON l.custid = b.CustId
            WHERE b.bettype = @BetType
                  AND b.statusid = 0
                  AND ((@IsTest = 1
                        AND currency = 20)
                       OR (@IsTest = 0
                           AND currency <> 20))
                  AND b.transdate > l.alerttime
            GROUP BY b.custid
            ORDER BY WinningAmount DESC;

     -- SELECT 
     SELECT s.custid, 
            username, 
            currencyname, 
            s.winningamount, 
            companyloseamount, 
            totalbets, 
            totalselectionsmin, 
            totalselectionsmax, 
            odds, 
            housept, 
            ISNULL(p.AlertAmount, 0) LastAlertAmount, 
            ISNULL(r.WinningAmount, 0) AS AmountFromLastAlert,
			COMPRESS((SELECT TransList AS 'tl',
					CASE WHEN @IsSMP = 1 THEN 'Single Match Parlay' ELSE
						CASE WHEN WinningAmount >= 1000000 AND WinningAmount < 2000000 THEN 'Orange Level' 
							 WHEN WinningAmount >= 2000000 AND WinningAmount < 3000000 THEN 'Yellow Level'
							 WHEN WinningAmount >= 3000000 AND WinningAmount < 4000000 THEN 'Red 1 Level'
							 WHEN WinningAmount >= 4000000 AND WinningAmount < 5000000 THEN 'Red 2 Level'
							 WHEN WinningAmount >= 5000000 THEN 'Red 3 Level'
						END 
					END AS 'sp',
					CAST(totalselectionsmin AS VARCHAR) + '-' + CAST(totalselectionsmax AS VARCHAR) AS 'sl',
					Odds AS 'od',
					totalbets AS 'tb',
					TotalMemberStake AS 'ms',
					WinningAmount AS 'pw',
					CompanyLoseAmount AS 'pl'
				FROM #sumtotal t
				WHERE t.custid = s.custid
					FOR JSON PATH
					,INCLUDE_NULL_VALUES
				)) TransInfo
     FROM #sumtotal s
          LEFT JOIN #sumtotalfromlastalert r ON s.custid = r.custid
          LEFT JOIN #lastalert p WITH(NOLOCK) ON s.custid = p.custid;
     DROP TABLE #sumtotal;
     DROP TABLE #sumtotalfromlastalert;
     DROP TABLE #lastalert;
GO