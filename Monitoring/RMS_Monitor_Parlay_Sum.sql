ALTER PROCEDURE [dbo].[RMS_Monitor_Parlay_Sum]
	@bettype		INT = 9, --Mix Parlay = 9, System Parlay = 29
	@winlostdate	DATETIME,
	@max_transid	BIGINT = 0 OUTPUT
AS
	/*
		Created: Johnson
		Date: 2012-05-24
		Task : Get report summary
		DB: DBRMS/bodb_RMS
		
		Revisions:
			- 20120621@Viet: revise SP
			- 20130123@Johnson: move sp from DB054.bodb02 to DBRMS.bodb_RMS
		Parameter's Explanation:
	*/
SET NOCOUNT ON

DECLARE @startRun datetime  	
SET @startRun=CURRENT_TIMESTAMP

CREATE TABLE #tmpSum (rn int, statusid tinyint, status varchar(10), events int, tickets int, turnover money, winloss money, companyWL money)
CREATE TABLE #tmpBettrans (refno bigint primary key, statusid tinyint, actual_stake money, actualrate smallmoney, winlost money, tpositiontaking smallmoney )
DECLARE @matchid int

SELECT @max_transid = max(transid)
FROM rmBettrans WITH(NOLOCK)
WHERE bettype = @bettype 
	AND matchid = @bettype
	AND statusid IN (0,111,112,113)
	AND currency <> 20
	AND winlostdate >= @winlostdate


INSERT INTO #tmpBettrans (refno, statusid, actual_stake, actualrate, winlost, tpositiontaking)
SELECT refno, statusid, actual_stake, actualrate, winlost, tpositiontaking
FROM rmBettrans WITH(NOLOCK)
WHERE bettype = @bettype 
	AND matchid = @bettype
	AND statusid IN (0,111,112,113)
	AND currency <> 20
	AND winlostdate >= @winlostdate
	AND transid <= @max_transid

INSERT INTO #tmpSum(rn, statusid, status, events, tickets, turnover, winloss ,companyWL)
select 1, 1, 'Total', 0, 0, 0,0,0
UNION   
select 2, 0, 'Running', 0, 0, 0,0,0
UNION   
select 3, 100, 'Settled', 0, 0, 0,0,0
UNION   
select 4, 112, 'Won', 0, 0, 0,0,0
UNION   
select 5, 113, 'Lose', 0, 0, 0,0,0 
UNION   
select 6, 111, 'Draw', 0, 0, 0,0,0 

;WITH A AS (  
	SELECT statusid
		,count(1) as tickets
		,sum(actual_stake*actualrate) as turnover
		,sum(case when statusid in (0,111) THEN 0 ELSE -(winlost - actual_stake)*actualrate END) as winloss
		,sum(case when statusid in (0,111) THEN 0 ELSE -(winlost - actual_stake)*actualrate*(1-tpositiontaking) END) as companyWL
	FROM #tmpBettrans 
	GROUP BY statusid
)  
UPDATE #tmpSum
SET  
	tickets = isnull(A.tickets,0),  
	turnover = isnull(A.turnover,0),  
	winloss = isnull(A.winloss,0),
	companyWL = isnull(A.companyWL,0)  
FROM A
WHERE #tmpSum.statusid = A.statusid

declare @runningCNT int, @wonCNT int, @loseCNT int, @settleCNT int, @totalCNT int

declare @B as table(statusid tinyint, matchid int)
INSERT INTO @B(statusid, matchid)
SELECT distinct statusid, matchid
FROM (
	select b.statusid, matchid
	from bodb02.dbo.bettransm bm with(nolock)
		inner join #tmpBettrans b on bm.refno = b.refno
	UNION ALL 
	select b.statusid, matchid
	from bodb02.dbo.bettransm14 bm with(nolock)
		inner join #tmpBettrans b on bm.refno = b.refno
) x	

SELECT @runningCNT = sum(case when statusid = 0 then 1 else 0 end)
	,@wonCNT = sum(case when statusid = 112 then 1 else 0 end)
	,@loseCNT = sum(case when statusid = 113 then 1 else 0 end)
	,@totalCNT = COUNT(distinct matchid)
FROM @B	

SELECT @settleCNT = COUNT(distinct matchid)
from @B
where statusid <> 0

UPDATE #tmpSum
set events = case statusid when 0 then @runningCNT
					when 112 then @wonCNT
					when 113 then @loseCNT
					when 100 then @settleCNT
					when 1 then @totalCNT
				else events end

;WITH C AS (
	select sum(tickets) as tickets1
		,sum(turnover) as turnover1
		,sum(case when statusid in (111,112,113) then tickets else 0 end) as tickets100
		,sum(case when statusid in (111,112,113) then turnover else 0 end) as turnover100
		,sum(case when statusid in (111,112,113) then winloss else 0 end) as winloss100
		,sum(case when statusid in (111,112,113) then companyWL else 0 end) as companyWL100
	from #tmpSum
)
update #tmpSum
set tickets = case statusid when 1 then tickets1 else tickets100 end
	,turnover = case statusid when 1 then turnover1 else turnover100 end
	,winloss = case statusid when 1 then 0 else winloss100 end
	,companyWL = case statusid when 1 then 0 else companyWL100 end
FROM C	
where #tmpSum.statusid in (1, 100)

select status, events, tickets, turnover, winloss, companyWL
FROM #tmpSum
WHERE statusid <> 111
order by rn
		
drop table #tmpBettrans
drop table #tmpSum

SELECT DATEDIFF(MILLISECOND,@startRun,CURRENT_TIMESTAMP)


GO
GRANT EXECUTE ON [dbo].[RMS_Monitor_Parlay_Sum] TO [bodbRMSNet]