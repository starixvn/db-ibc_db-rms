ALTER PROCEDURE [dbo].[RMS_Monitor_Parlay_SelectionByTicket_League_Event]
	@bettype		INT = 9,
	@sporttype		INT = 0,	
	@winlostdate	DATETIME,
	@selection		INT = 2,
	@leagueid		INT,	
	@max_transid	BIGINT	
AS
	/*
		Created: Johnson
		Date: 2012-08-01
		Task: Get report top events by top tickets and league
		DB: DBRMS/bodb_RMS
		
		Revisions:
			- 20130123@Johnson: move sp from DB054.bodb02 to DBRMS.bodb_RMS
		Parameter's Explanation:
			- @sporttype = 0 : all sports
						= 1 : soccer only
						= 2 : Other sports
						= 3 : combined sports
			- @leagueid: id of league to filter
		exec RMS_Monitor_Parlay_SelectionByTicket_League_Event 9,1,'2012-07-01',3,24451,3760010937
	*/
SET NOCOUNT ON
	DECLARE @tmp_Bettrans TABLE (refno bigint primary key, selection int, sporttype int)
	DECLARE @TopEvent TABLE( matchid int, tickets int)
	
	DECLARE @matchid INT
	
	IF @bettype = 9 
		SELECT @matchid = 9
	ELSE IF @bettype = 29 
		SELECT @matchid = 29
		
		
	INSERT INTO @tmp_Bettrans (refno, selection, sporttype)
	SELECT refno, right(betcheck,len(betcheck)-1), liveawayscore
	FROM rmBettrans WITH(NOLOCK)
	WHERE matchid = @matchid
		AND statusid = 0
		AND currency <> 20
		AND winlostdate >= @winlostdate
		AND transid <= @max_transid

	IF @sporttype <> 0
		DELETE @tmp_Bettrans WHERE sporttype <> @sporttype
	
	DELETE @tmp_Bettrans WHERE selection <> @selection
		
	INSERT INTO @TopEvent (matchid, tickets)
	SELECT top 10 matchid, count(1)
	FROM(	
			SELECT bm.refno, bm.matchid
			FROM @tmp_Bettrans t
				INNER JOIN bodb02.dbo.bettransm bm WITH(NOLOCK) ON t.refno = bm.refno
				INNER JOIN bodb02.dbo.match m WITH(NOLOCK) ON bm.matchid = m.matchid
			WHERE m.leagueid = @leagueid
			UNION ALL
			SELECT bm.refno, bm.matchid
			FROM @tmp_Bettrans t
				INNER JOIN bodb02.dbo.bettransm14 bm WITH(NOLOCK) ON t.refno = bm.refno
				INNER JOIN bodb02.dbo.match14 m WITH(NOLOCK) ON bm.matchid = m.matchid
			WHERE m.leagueid = @leagueid
		)r
	GROUP BY matchid
	ORDER BY count(1) DESC
	
	SELECT *
	FROM
	(
		SELECT m.matchid, homeid, awayid, leagueid, t.tickets
		FROM bodb02.dbo.match m WITH(NOLOCK)
			INNER JOIN @TopEvent t ON m.matchid = t.matchid	
		UNION 
		SELECT m.matchid, homeid, awayid, leagueid, t.tickets
		FROM bodb02.dbo.match14 m WITH(NOLOCK)
			INNER JOIN @TopEvent t ON m.matchid = t.matchid
	)r
	ORDER BY tickets DESC
	
	
GO
GRANT VIEW DEFINITION ON [dbo].[RMS_Monitor_Parlay_SelectionByTicket_League_Event] TO [vnteam]
GO
GRANT EXECUTE ON [dbo].[RMS_Monitor_Parlay_SelectionByTicket_League_Event] TO [bodbRMSNet]