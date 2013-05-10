ALTER PROCEDURE [dbo].[RMS_Monitor_Parlay_SelectionByTicket_Event_Bettype]
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
		DB: DB054.bodb02
		
		Revisions:
			- 20130123@Johnson: move sp from DB054.bodb02 to DBRMS.bodb_RMS
		Parameter's Explanation:
			- @sporttype = 0 : all sports
							= 1 : soccer only
							= 2 : Other sports
							= 3 : combined sports
			EXEC RMS_Monitor_Parlay_SelectionByTicket_Event_Bettype 9,1,'2012-07-01',3,2207345,3780712395
	*/
SET NOCOUNT ON
-------------------------------
	DECLARE @tmp_Bettrans TABLE (refno bigint primary key, selection int, sporttype int)
	DECLARE @T TABLE(bettype int, cnt int)	
	DECLARE @TopBettype TABLE( bettype int, tickets int, margin decimal(5,4), rn int)
	
	DECLARE @matchid2 INT
	
	IF @bettype = 9 
		SELECT @matchid2 = 9
	ELSE IF @bettype = 29 
		SELECT @matchid2 = 29
		
		
	INSERT INTO @tmp_Bettrans (refno, selection, sporttype)
	SELECT refno, right(betcheck,len(betcheck)-1), liveawayscore
	FROM rmBettrans WITH(NOLOCK)
	WHERE matchid = @matchid2
		AND statusid = 0
		AND currency <> 20
		AND winlostdate >= @winlostdate
		AND transid <= @max_transid
	
	IF @sporttype <> 0
		DELETE @tmp_Bettrans WHERE sporttype <> @sporttype
	
	DELETE @tmp_Bettrans WHERE selection <> @selection
	
	INSERT INTO @T( bettype , cnt)
		SELECT bettype, count(1) as cnt
		FROM @tmp_Bettrans t
			INNER JOIN bodb02.dbo.bettransm bm WITH(NOLOCK) ON bm.refno = t.refno
		WHERE matchid = @matchid
		GROUP BY bettype
	
	DECLARE @total INT
	SELECT @total = ISNULL(SUM(cnt),0)
	FROM @T
	
	SELECT @total = ISNULL(NULLIF(@total,0)	,1)
	
	INSERT INTO @TopBettype( bettype, tickets, margin, rn)
	SELECT TOP 5 bettype, cnt, cnt*1.0/@total ,ROW_NUMBER() OVER (ORDER BY cnt DESC)
	FROM @T	
	
	INSERT INTO @TopBettype( bettype, tickets, margin, rn)
	SELECT 0 as bettype, ISNULL(SUM(cnt),0),ISNULL(SUM(cnt),0)*1.0/@total, 6
	FROM @T
	WHERE bettype NOT IN (SELECT bettype FROM @TopBettype)
	
	SELECT * FROM @TopBettype
	ORDER BY rn ASC
	
GO
GRANT VIEW DEFINITION ON [dbo].[RMS_Monitor_Parlay_SelectionByTicket_Event_Bettype] TO [vnteam]
GO
GRANT EXECUTE ON [dbo].[RMS_Monitor_Parlay_SelectionByTicket_Event_Bettype] TO [bodbRMSNet]
