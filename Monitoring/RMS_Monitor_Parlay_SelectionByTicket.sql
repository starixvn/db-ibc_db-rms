ALTER PROCEDURE [dbo].[RMS_Monitor_Parlay_SelectionByTicket]
	@winlostdate	DATETIME,
	@max_transid	BIGINT = 0
AS
/*
	Created: Johnson
	Date: 2012-05-21
	Task : Calculate report top selections by tickets
	DB: DBRMS/bodb_RMS
	
	Revisions:
		-20130123@Johnson: Move sp from DB054.bodb02 to DBRMS.bodb_RMS
	Paramter's Explanation:
*/
SET NOCOUNT ON
	----------------
	CREATE TABLE #tmp_Bettrans (refno bigint primary key, selection int, sporttype int)
	DECLARE @tmp_Selection table (Selection INT)
	DECLARE @TopSelection table (sporttype int , Selection int, Notickets int)
		
	-- Get all running Mix Parlay tickets
	INSERT INTO #tmp_Bettrans(refno, selection, sporttype)
	SELECT refno, right(betcheck,len(betcheck)-1), liveawayscore-- mark sporttype 
	FROM rmBettrans WITH (NOLOCK)
	WHERE matchid = 9
		AND statusID = 0
		AND winlostdate >= @winlostdate
		AND currency <> 20
		AND transid <= @max_transid

	-- Get top 10 selection types having highest running Parlay tickets (all sports)
	INSERT INTO @tmp_Selection (selection)
	SELECT TOP 10 selection 
	FROM #tmp_Bettrans
	GROUP BY selection
	ORDER BY count(1) DESC

	-- calculate selection by tickets by separate sports
	INSERT INTO @TopSelection (sporttype, selection, NoTickets)	
	SELECT sporttype, selection, count(1)
	FROM #tmp_bettrans 
	WHERE selection IN (SELECT selection FROM @tmp_Selection)
	GROUP BY sporttype, selection
	UNION ALL
	SELECT 0 as sporttype , selection, count(1)
	FROM #tmp_Bettrans
	WHERE selection IN (SELECT selection From @tmp_Selection)
	GROUP BY selection
	
	SELECT selection,isnull([All_Sports],0) as [All_Sports],isnull([Soccer_Only],0) as [Soccer_Only],isnull([Other_Sports],0) as [Other_Sports],isnull([Combined_Sports],0) as [Combined_Sports]
	FROM(	
	SELECT CASE sporttype WHEN 0 THEN 'All_Sports'
						WHEN 1 THEN 'Soccer_Only'
						WHEN 2 THEN 'Other_Sports'
						WHEN 3 THEN 'Combined_Sports' END as sport,
			--sporttype,
			selection,
			NoTickets
	FROM @TopSelection
	) r PIVOT (
		SUM(NoTickets)
		FOR Sport IN ([All_Sports],[Soccer_Only],[Other_Sports],[Combined_Sports])
	) m
	
	DROP TABLE #tmp_Bettrans
GO
GRANT EXECUTE ON [dbo].[RMS_Monitor_Parlay_SelectionByTicket] TO [bodbRMSNet]
GO
GRANT VIEW DEFINITION ON [dbo].[RMS_Monitor_Parlay_SelectionByTicket] TO [vnteam]

