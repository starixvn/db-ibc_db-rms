ALTER PROCEDURE [dbo].[RMS_Monitor_Parlay_SelectionByTurnover_League]
	@selection INT = 2,
	@sporttype INT = 0,
	@winlostdate DATETIME,
	@max_transid BIGINT = 0
AS
	/*
		Created: Johnson
		Date: 2012-05-23
		Task: Get report top leagues by selection and turnover 
		DB: DBRMS/bodb_RMS
				
		Revisions:
			- 20130123@Johnson: move sp from DB054.bodb02 to DBRMS.bodb_RMS
		Parameter's Explanation:
			@sporttype = 0: All sports
						= 1: Soccer only
						= 2: Other sports
						= 3: Combined sports
	*/
SET NOCOUNT ON
----------------
	DECLARE @tmp_Bettrans TABLE(refno bigint primary key, selection int, sporttype int, turnover money)

	INSERT INTO @tmp_Bettrans (refno, selection, sporttype, turnover)
	SELECT refno, right(betcheck,len(betcheck)-1), liveawayscore, actual_stake*actualrate
	FROM rmBettrans WITH(NOLOCK)
	WHERE matchid = 9 
		AND statusid = 0
		AND winlostdate >= @winlostdate
		AND currency <> 20
		AND transid <= @max_transid
		
	IF @sporttype <> 0
		DELETE @tmp_Bettrans WHERE sporttype <> @sporttype
	
	DELETE @tmp_Bettrans WHERE selection <> @selection
	
	SELECT top 5 leagueid, SUM(turnover) as turnover
	FROM
		(
			SELECT distinct b.refno, leagueid, turnover
			FROM bodb02.dbo.bettransm bm WITH(NOLOCK)
				INNER JOIN @tmp_Bettrans b ON bm.refno = b.refno	
				INNER JOIN bodb02.dbo.match m WITH(NOLOCK) ON bm.matchid = m.matchid
			UNION 
			SELECT distinct b.refno, leagueid, turnover
			FROM bodb02.dbo.bettransm14 bm WITH(NOLOCK)
				INNER JOIN @tmp_Bettrans b ON bm.refno = b.refno	
				INNER JOIN bodb02.dbo.match14 m WITH(NOLOCK) ON bm.matchid = m.matchid	
		)r
	GROUP BY leagueid
	ORDER BY sum(turnover) DESC
	
GO
GRANT EXECUTE ON [dbo].[RMS_Monitor_Parlay_SelectionByTurnover_League] TO [bodbRMSNet]
GO
GRANT VIEW DEFINITION ON [dbo].[RMS_Monitor_Parlay_SelectionByTurnover_League] TO [vnteam]