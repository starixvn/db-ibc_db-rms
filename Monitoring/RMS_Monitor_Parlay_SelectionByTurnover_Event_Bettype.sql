ALTER PROCEDURE [dbo].[RMS_Monitor_Parlay_SelectionByTurnover_Event_Bettype]
	@bettype		INT = 9,
	@sporttype		INT = 0,	
	@winlostdate	DATETIME,
	@selection		INT = 2,
	@matchid		INT,
	@max_transid	BIGINT	
AS
	/*
		Created: Johnson
		Date: 2012-08-07
		Task: Get report top bettype by event 
		DB: DBRMS/bodb_RMS
		
		Revisions:
			- 20130123@Johnson: move sp from DB054.bodb02 to DBRMS.bodb_RMS
		Parameter's Explanation:
			- @sporttype = 0 : all sports
							= 1 : soccer only
							= 2 : Other sports
							= 3 : combined sports
		EXEC RMS_Monitor_Parlay_SelectionByTurnover_Event_Bettype 9,1,'2012-07-01',3,2207345,3780712395

	*/ 
SET NOCOUNT ON
-------------------------------
	DECLARE @tmp_Bettrans TABLE (refno bigint primary key, selection int, sporttype int, turnover money)
	DECLARE @T TABLE(bettype int, turnover money)	
	DECLARE @TopBettype TABLE( bettype int, turnover money, margin decimal(5,4), rn int)
	
	DECLARE @matchid2 INT
	
	IF @bettype = 9 
		SELECT @matchid2 = 9
	ELSE IF @bettype = 29 
		SELECT @matchid2 = 29
	
		
	INSERT INTO @tmp_Bettrans (refno, selection, sporttype, turnover)
	SELECT refno, right(betcheck,len(betcheck)-1), liveawayscore, actual_stake*actualrate
	FROM rmBettrans WITH(NOLOCK)
	WHERE matchid = @matchid2
		AND statusid = 0
		AND currency <> 20
		AND winlostdate >= @winlostdate
		AND transid <= @max_transid
	
	IF @sporttype <> 0
		DELETE @tmp_Bettrans WHERE sporttype <> @sporttype
	
	DELETE @tmp_Bettrans WHERE selection <> @selection
				
	INSERT INTO @T( bettype , turnover)
		SELECT bettype, sum(turnover) as turnover
		FROM (
				SELECT bm.bettype , b.turnover
				FROM bodb02.dbo.bettransm bm WITH(NOLOCK) 
					INNER JOIN @tmp_Bettrans b ON b.refno = bm.refno
				WHERE matchid = @matchid
				UNION ALL
				SELECT bm.bettype , b.turnover
				FROM bodb02.dbo.bettransm14 bm WITH(NOLOCK) 
					INNER JOIN @tmp_Bettrans b ON b.refno = bm.refno
				WHERE matchid = @matchid
		)r
		GROUP BY bettype
	
	DECLARE @total money
	SELECT @total = ISNULL(SUM(turnover),0)
	FROM @T
	
	SELECT @total = ISNULL(NULLIF(@total,0)	,1)
	
	INSERT INTO @TopBettype( bettype, turnover, margin, rn)
	SELECT TOP 5 bettype, turnover, turnover/@total ,ROW_NUMBER() OVER (ORDER BY turnover DESC)
	FROM @T	
	
	INSERT INTO @TopBettype( bettype, turnover, margin, rn)
	SELECT 0 as bettype, ISNULL(SUM(turnover),0),ISNULL(SUM(turnover),0)/@total, 6
	FROM @T
	WHERE bettype NOT IN (SELECT bettype FROM @TopBettype)
	
	SELECT * FROM @TopBettype
	ORDER BY rn ASC
	

GO
GRANT VIEW DEFINITION ON [dbo].[RMS_Monitor_Parlay_SelectionByTurnover_Event_Bettype] TO [vnteam]
GO
GRANT EXECUTE ON [dbo].[RMS_Monitor_Parlay_SelectionByTurnover_Event_Bettype] TO [bodbRMSNet]