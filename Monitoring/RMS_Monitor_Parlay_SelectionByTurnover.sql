ALTER PROCEDURE [dbo].[RMS_Monitor_Parlay_SelectionByTurnover]
	@winlostdate	DATETIME,
	@max_transid	BIGINT = 0
AS
	/*
		Created: Johnson
		Date: 2012-05-22
		Task : Get report top selection by turnover
		DB: DBRMS/bodb_RMS
			
		Revisions:
			- 20120913@Viet: revise SP
			- 20130123@Johnson: move sp from DB054.bodb02 to DBRMS.bodb_RMS
		Parameter's Explanation:
	*/
SET NOCOUNT ON

declare @tempData as table (refno bigint primary key, turnover money, sporttype int, selection int)
INSERT INTO @tempData(refno, turnover, sporttype, selection)
SELECT b.refno, b.actual_stake * b.actualrate, b.liveawayscore, right(betcheck,len(betcheck)-1)
FROM rmBettrans b with(nolock)	
WHERE b.winlostdate >= @winlostdate
	and b.matchid = 9
	and b.statusID = 0
	and b.currency <> 20
	and b.transid <= @max_transid
	
DECLARE @tmp_Selection table (Selection int, turnover money)
INSERT INTO @tmp_Selection (selection, turnover)
select top 10 selection, sum(turnover) 
FROM @tempData
group by selection
order by sum(turnover) desc

SELECT selection,isnull([All_Sports],0) as [All_Sports],isnull([Soccer_Only],0) as [Soccer_Only],isnull([Other_Sports],0) as [Other_Sports],isnull([Combined_Sports],0) as [Combined_Sports]
FROM (	
	SELECT CASE sporttype WHEN 0 THEN 'All_Sports'
						WHEN 1 THEN 'Soccer_Only'
						WHEN 2 THEN 'Other_Sports'
						WHEN 3 THEN 'Combined_Sports' END as sport,
			selection,
			Turnover
	FROM (
			SELECT sporttype, selection, sum(turnover) as turnover
			FROM @tempData
			WHERE selection IN (SELECT selection FROM @tmp_Selection)
			GROUP BY sporttype, selection
					
			UNION ALL
			
			SELECT 0 as sporttype, selection, turnover
			FRom @tmp_Selection			
	)x
) r PIVOT (
	SUM(Turnover)
	FOR Sport IN ([All_Sports],[Soccer_Only],[Other_Sports],[Combined_Sports])
) m

GO
GRANT EXECUTE ON [dbo].[RMS_Monitor_Parlay_SelectionByTurnover] TO [bodbRMSNet]