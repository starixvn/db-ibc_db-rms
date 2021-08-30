/*<info serverAlias="DBRMS-bodb_RMS" executers="bodbRMSNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[RMS_Similar_Betlist_Alert]
AS
/*
	Created: 20160426@Winnie
	DB: DBRMS-bodb_RMS
	Task: Get similar bets combo parlay tickets
			
	Revisions:
		- 20210029@Danny: Support filter tickets having 100% of selections Similar Bets [RedmineID: #159304]

	EXEC RMS_Similar_Betlist_Alert
*/
BEGIN
SET NOCOUNT ON
DECLARE @MoveBetsDay SMALLDATETIME, @BalanceUpDay SMALLDATETIME, @ErrCode INT, @ErrMsg VARCHAR(4000)

DECLARE @MBBU TABLE (BalanceUpDay SMALLDATETIME, MoveBetsDay SMALLDATETIME)
INSERT INTO @MBBU (BalanceUpDay, MoveBetsDay)
EXEC bodb02.dbo.Age_SelBalanceUpDay

	SELECT @MoveBetsDay = MoveBetsDay, @BalanceUpDay = BalanceUpDay FROM @MBBU

CREATE TABLE #rmRunningTicketMonitor (transid BIGINT, selection VARBINARY(16), PotentialWinningAnt MONEY, NoSelection SMALLINT,  SportType VARCHAR(200) )

CREATE TABLE #main (transid BIGINT, PotentialWinningAnt MONEY ,combo INT , refno BIGINT, transid2 BIGINT)
INSERT INTO #main (transid, PotentialWinningAnt, combo, refno, transid2)
SELECT  t1.transid , t1.stake * (t1.odds2 - 1)* t1.actualrate  AS PotentialWinningAnt,  t1.combo, t1.refno ,transid2
from rmBettrans t1 WITH(NOLOCK) 
where t1.bettype = 29  
		and t1.statusid = 0 
		AND t1.currency <> 20 

CREATE TABLE #temp (transid BIGINT, Extra VARCHAR(500))
CREATE CLUSTERED INDEX idx_transid_#temp ON #temp(transid) 

INSERT INTO #temp (transid, Extra)
SELECT t1.transid, x.Extra
from #main t1 WITH(NOLOCK) 
CROSS APPLY(

		SELECT  CAST(t2.matchid AS VARCHAR(15))+'-'+ CAST(t2.betteam AS VARCHAR(5)) +'-' +CAST (t2.bettype AS VARCHAR(4)) AS Extra
		from bodb02.dbo.bettransm t2 WITH(NOLOCK) 
		where t1.refno = t2.refno AND (t2.winlostdate > @MoveBetsDay OR t2.winlostdate IS NULL)

		UNION ALL

		SELECT  CAST(t3.matchid AS VARCHAR(15))+'-'+ CAST(t3.betteam AS VARCHAR(5)) +'-' +CAST (t3.bettype AS VARCHAR(4))
		from bodb02.dbo.bettransm14 t3 WITH(NOLOCK) 
		where t1.refno = t3.refno AND  t3.custID > 0 AND t3.winlostdate between @BalanceUpDay AND @MoveBetsDay

		UNION ALL

		SELECT CAST(t3.matchid AS VARCHAR(15))+'-'+ CAST(t3.betteam AS VARCHAR(5)) +'-' +CAST (t3.bettype AS VARCHAR(4))
		from dbo.rmBettransm_bk t3 WITH(NOLOCK) 
		where t1.refno = t3.refno AND t3.winlostdate < @BalanceUpDay
		) x 


INSERT INTO #rmRunningTicketMonitor(transid , selection , PotentialWinningAnt , NoSelection , SportType )
select  t1.transid,
		hashbytes('MD5',(SELECT  ',' + t.extra 
			from #temp t
			WHERE t.transid = t1.transid
			FOR XML PATH(''), TYPE
			).value('.', 'NVARCHAR(MAX)'))
		selection, 
		t1.PotentialWinningAnt, 
		t1.combo,
		CASE WHEN t1.transid2 = 1  THEN 'Soccer Only'
			WHEN t1.transid2 = -4 THEN'Virtual Soccer Only'
			WHEN t1.transid2 = -5 THEN'Virtual Basketball Only'
			ELSE 'Others'
			END  AS SportType
	from #main t1 WITH(NOLOCK) 


CREATE CLUSTERED INDEX cix_#rmRunningTicketMonitor_selection ON #rmRunningTicketMonitor(selection,sportType)


SELECT	t.selection, t.NoSelection,
		t.SportType,
		SUM(ISNULL(t.PotentialWinningAnt,0)) PotentialWinningAmt,
		STUFF((SELECT  ',' + CAST(t1.transid  AS VARCHAR(15))
			FROM #rmRunningTicketMonitor t1
			WHERE t.selection = t1.selection AND t.NoSelection = t1.NoSelection AND t.SportType = t1.SportType
			FOR XML PATH(''), TYPE
			).value('.', 'NVARCHAR(MAX)')  
		,1,1,'') transList
FROM	#rmRunningTicketMonitor t
GROUP BY t.selection, t.NoSelection, t.SportType
HAVING SUM(ISNULL(t.PotentialWinningAnt,0)) >= CASE  WHEN SportType = 1 THEN 200000
													 WHEN SportType = -4 THEN 50000
													 WHEN SportType = -5 THEN 50000
													 ELSE 100000 END

DROP TABLE  #main
DROP TABLE  #rmRunningTicketMonitor
DROP TABLE  #temp

--------------------------------------------------------------
END

