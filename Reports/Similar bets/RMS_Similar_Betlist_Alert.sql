/*<info serverAlias="DBRMS-bodb_RMS" executers="bodbRMSNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[RMS_Similar_Betlist_Alert]
AS
/*
	Created: 20160426@Winnie
	DB: DBRMS-bodb_RMS
	Task: Get similar bets combo parlay tickets
			
	Revisions:
		- 20210829@Danny: Support filter tickets having 100% of selections Similar Bets [RedmineID: #159304]
		- 20210910@Danny: Enhance Similar Betlist Alert [RedmineID: #161419]
		- 20211018@Danny: Notification by Group based on SportType [RedmineID: #163354]
		- 20211208@Danny: Add Odds Info [RedmineID: #165789]
		- 20220210@Danny: Change alert threshold of 2 selections parlay ticket [RedmineID: #168366]
		- 20220829@Danny: Extend data length for support new transid [RedmineID: #177153]
		- 20230620@Cherry: Manage Alert (#189147)

	EXEC RMS_Similar_Betlist_Alert
*/
BEGIN
SET NOCOUNT ON
DECLARE @MoveBetsDay SMALLDATETIME, @BalanceUpDay SMALLDATETIME, @ErrCode INT, @ErrMsg VARCHAR(4000)

DECLARE @yesterday DATETIME
SELECT  @yesterday = CONVERT(DATE, DATEADD(DAY, -1, GETDATE()))

DECLARE @MBBU TABLE (BalanceUpDay SMALLDATETIME, MoveBetsDay SMALLDATETIME)
INSERT INTO @MBBU (BalanceUpDay, MoveBetsDay)
EXEC bodb02.dbo.Age_SelBalanceUpDay

	SELECT @MoveBetsDay = MoveBetsDay, @BalanceUpDay = BalanceUpDay FROM @MBBU

CREATE TABLE #rmRunningTicketMonitor (transid BIGINT, selection VARBINARY(16), PotentialWinningAnt MONEY, NoSelection SMALLINT,  
									SportType VARCHAR(200) ,TotalMemberStake MONEY, SportTypeID INT, Odds MONEY, CompanyLoseAmt MONEY)

CREATE TABLE #main (transid BIGINT, PotentialWinningAnt MONEY ,combo INT , refno BIGINT, 
					transid2 BIGINT, TotalMemberStake MONEY, Odds MONEY, CompanyLoseAmt MONEY)
CREATE CLUSTERED INDEX cix_#main ON #main(transid) 

INSERT INTO #main (transid, PotentialWinningAnt, combo, refno, transid2, TotalMemberStake, Odds, CompanyLoseAmt)
SELECT  t1.transid , t1.stake * (t1.odds2 - 1)* t1.actualrate  AS PotentialWinningAnt,  t1.combo, t1.refno ,transid2, 
	(t1.stake * t1.actualrate) AS TotalMemberStake, (t1.odds2 * t1.TotalBet) AS  Odds,
	t1.stake * (t1.odds2 - 1) * t1.actualrate * (1 - t1.tpositiontaking) AS CompanyLoseAmt
FROM rmBettrans t1 WITH(NOLOCK) 
WHERE   t1.winlostdate > @yesterday
		AND t1.bettype = 29  
		and t1.statusid = 0 
		AND t1.currency <> 20 

CREATE TABLE #temp (transid BIGINT, Extra VARCHAR(500))
CREATE CLUSTERED INDEX idx_transid_#temp ON #temp(transid) 

INSERT INTO #temp (transid, Extra)
SELECT t1.transid, x.Extra
from #main t1 WITH(NOLOCK) 
CROSS APPLY(

		SELECT  CAST(t2.matchid AS VARCHAR(20))+'-'+ CAST(t2.betteam AS VARCHAR(5)) +'-' +CAST (t2.bettype AS VARCHAR(4)) AS Extra
		from bodb02.dbo.bettransm t2 WITH(NOLOCK) 
		where t1.refno = t2.refno AND (t2.winlostdate > @MoveBetsDay OR t2.winlostdate IS NULL)

		UNION ALL

		SELECT  CAST(t3.matchid AS VARCHAR(20))+'-'+ CAST(t3.betteam AS VARCHAR(5)) +'-' +CAST (t3.bettype AS VARCHAR(4))
		from bodb02.dbo.bettransm14 t3 WITH(NOLOCK) 
		where t1.refno = t3.refno AND  t3.custID > 0 AND t3.winlostdate between @BalanceUpDay AND @MoveBetsDay

		UNION ALL

		SELECT CAST(t3.matchid AS VARCHAR(20))+'-'+ CAST(t3.betteam AS VARCHAR(5)) +'-' +CAST (t3.bettype AS VARCHAR(4))
		from dbo.rmBettransm_bk t3 WITH(NOLOCK) 
		where t1.refno = t3.refno AND t3.winlostdate < @BalanceUpDay
		) x 


INSERT INTO #rmRunningTicketMonitor(transid , selection , PotentialWinningAnt , NoSelection , SportType ,TotalMemberStake, SportTypeID, Odds, CompanyLoseAmt)
select  t1.transid,
		hashbytes('MD5',(SELECT  ',' + t.extra 
			from #temp t
			WHERE t.transid = t1.transid
			ORDER BY t.extra 
			FOR XML PATH(''), TYPE
			).value('.', 'NVARCHAR(MAX)'))
		selection, 
		t1.PotentialWinningAnt, 
		t1.combo,
		CASE WHEN t1.transid2 = 1  THEN 'Soccer Only'
			 WHEN t1.transid2 = -4 THEN 'Virtual Soccer Only'
			 WHEN t1.transid2 = -5 THEN 'Virtual Basketball Only'
			 WHEN t1.transid2 = -3 THEN 'Combined Sports'
			 WHEN t1.transid2 = -1 THEN 'Combined Other Sports'
			 WHEN t1.transid2 NOT IN (1, -4, -5, -3, -1) THEN s.SportName
			END  AS SportType,
		t1.TotalMemberStake,
		transid2 AS SportTypeID,
		t1.Odds, 
		t1.CompanyLoseAmt
	from #main t1 WITH(NOLOCK) 
	LEFT JOIN bodb02.dbo.Sports s WITH(NOLOCK) ON t1.transid2 = s.SportType


CREATE CLUSTERED INDEX cix_#rmRunningTicketMonitor_selection ON #rmRunningTicketMonitor(selection,sportType)

CREATE TABLE #OddsInfo (selection VARBINARY(16), Odds MONEY)

;WITH t AS
(
	SELECT  t.selection, MAX(transid) AS transid
	FROM	#rmRunningTicketMonitor t
	GROUP BY t.selection
)INSERT INTO #OddsInfo  (selection, Odds)
SELECT t.selection, m.Odds
FROM t INNER JOIN #main m ON t.transid = m.transid

CREATE TABLE #result (selection VARBINARY(16), 
					NoSelection SMALLINT, 
					SportType VARCHAR(100), 
					PotentialWinningAmt MONEY, 
					transList NVARCHAR(MAX), 
					TotalMemberStake MONEY, 
					GroupName VARCHAR(100), 
					Odds MONEY, 
					CompanyLoseAmt MONEY)

;WITH d AS
(
SELECT	t.selection, t.NoSelection,
		t.SportType,
		SUM(ISNULL(t.PotentialWinningAnt,0)) PotentialWinningAmt,
		STUFF((SELECT  ',' + CAST(t1.transid  AS VARCHAR(30))
			FROM #rmRunningTicketMonitor t1
			WHERE t.selection = t1.selection AND t.NoSelection = t1.NoSelection AND t.SportType = t1.SportType
			FOR XML PATH(''), TYPE
			).value('.', 'NVARCHAR(MAX)')  
		,1,1,'') transList,
		SUM(ISNULL(t.TotalMemberStake,0)) TotalMemberStake,
		CASE WHEN t.SportTypeID IN (1, -4) THEN 'Soccer'
			 WHEN t.SportTypeID IN (2, -5) THEN 'Basketball'
			 ELSE 'Other' END AS GroupName,
		o.Odds,
		SUM(ISNULL(t.CompanyLoseAmt,0)) CompanyLoseAmt
FROM	#rmRunningTicketMonitor t
	INNER JOIN #OddsInfo o ON t.selection = o.selection
GROUP BY t.selection, t.NoSelection, t.SportType, t.SportTypeID,
		CASE WHEN t.SportTypeID IN (1, -4) THEN 'Soccer'
			WHEN t.SportTypeID IN (2, -5) THEN 'Basketball'
			ELSE 'Other' END, o.Odds
HAVING SUM(ISNULL(t.PotentialWinningAnt,0)) >= CASE  WHEN SportTypeID = 1 AND NoSelection > 2  THEN 500000
													 WHEN SportTypeID = -4 AND NoSelection > 2 THEN 50000
													 WHEN SportTypeID = -5 AND NoSelection > 2 THEN 50000
													 WHEN SportTypeID NOT IN (1, -4, -5) AND NoSelection > 2 THEN 100000
													 WHEN SportTypeID = 1 AND NoSelection = 2  THEN 100000
													 WHEN SportTypeID = -4 AND NoSelection = 2 THEN 30000
													 WHEN SportTypeID = -5 AND NoSelection = 2 THEN 10000
													 ELSE 30000 END
)
INSERT INTO #result (selection, NoSelection, SportType, PotentialWinningAmt, transList, TotalMemberStake, GroupName, Odds, CompanyLoseAmt)
SELECT d.selection, d.NoSelection, d.SportType, d.PotentialWinningAmt, d.transList, d.TotalMemberStake, d.GroupName, d.Odds, d.CompanyLoseAmt
FROM d

SELECT d.selection, d.NoSelection, d.SportType, d.PotentialWinningAmt, d.transList, d.TotalMemberStake, d.GroupName, d.Odds,
	COMPRESS((SELECT transList AS 'tl',
					SportType AS 'sp',
					NoSelection	AS 'sl',
					Odds AS 'od',
					TotalMemberStake AS 'ms',
					PotentialWinningAmt AS 'pw',
					CompanyLoseAmt AS 'pl'
				FROM #result t
				WHERE t.selection = d.selection AND t.NoSelection = d.NoSelection AND t.SportType = d.SportType AND t.Odds = d.Odds
					FOR JSON PATH
					,INCLUDE_NULL_VALUES
				)) Content
FROM #result d

DROP TABLE  #OddsInfo
DROP TABLE  #main
DROP TABLE  #rmRunningTicketMonitor
DROP TABLE  #temp
DROP TABLE  #result

END

