 ALTER PROCEDURE [dbo].[RMS_Monitor_Parlay_SelectionByTurnover_Currency_Event]
	@bettype		INT = 9,
	@sporttype		INT = 0,	
	@winlostdate	DATETIME,
	@selection		INT = 2,
	@currency		INT,
	@topcurrency	VARCHAR(20)='',
	@max_transid	BIGINT	
AS
	/*
		Created: Johnson
		Date: 2012-08-01
		Task: get report top events by top turnover and currency
		DB: DBRMS/bodb_RMS
		
		Revisions:
			- 20130123@Johnson: move sp from DB054.bodb02 to DBRMS.bodb_RMS
		Parameter's Explanation:
			- @sporttype = 0 : all sports
						= 1 : soccer only
						= 2 : Other sports
						= 3 : combined sports
			- @currency <> 0: currency to drill down
						= 0 : others currency not top currencies
			- @topcurrency: contain top currency by selection
							ex: '2,3,5,15,43'
			EXEC RMS_Monitor_Parlay_SelectionByTurnover_Currency_Event 9,1,'2012-07-01',3,5,'1,5,22,43,45',3760010937
	*/
SET NOCOUNT ON
-----------------------------
	DECLARE @tmp_Bettrans TABLE (refno bigint primary key, selection int, sporttype int ,currency VARCHAR(20), turnover money)
	CREATE TABLE #tmp_Bettransm  (refno bigint , matchid int)
	CREATE CLUSTERED INDEX ix_bettransm on #tmp_bettransm(refno)
	DECLARE @TopEvent TABLE( matchid int, turnover money)
	DECLARE @matchid INT
	
	IF @bettype = 9 
		SELECT @matchid = 9
	ELSE IF @bettype = 29 
		SELECT @matchid = 29
		
	IF @currency <> 0
	BEGIN
		INSERT INTO @tmp_Bettrans (refno, selection, sporttype, currency, turnover)
		SELECT refno, right(betcheck,len(betcheck)-1), liveawayscore, CurrencyName, actual_stake*actualrate
		FROM rmBettrans WITH(NOLOCK)
		WHERE matchid = @matchid
			AND statusid = 0
			AND winlostdate >= @winlostdate
			AND currency = @currency
			AND transid <= @max_transid
	END	
	ELSE
	BEGIN
		INSERT INTO @tmp_Bettrans (refno, selection, sporttype, currency, turnover)
		SELECT refno, right(betcheck,len(betcheck)-1), liveawayscore, CurrencyName, actual_stake*actualrate
		FROM rmBettrans WITH(NOLOCK)
		WHERE matchid = @matchid
			AND statusid = 0
			AND winlostdate >= @winlostdate
			AND currency NOT IN (SELECT val FROM strSplit(@topcurrency,','))
			AND currency <> 20
			AND transid <= @max_transid
	END
	
	IF @sporttype <> 0
		DELETE @tmp_Bettrans WHERE sporttype <> @sporttype
	
	DELETE @tmp_Bettrans WHERE selection <> @selection
	
	INSERT INTO #tmp_Bettransm (refno, matchid) 
		SELECT refno, matchid	
		FROM bodb02.dbo.Bettransm WITH(NOLOCK)
		WHERE refno IN (SELECT refno FROM @tmp_Bettrans)
	UNION ALL 
		SELECT refno, matchid
		FROM bodb02.dbo.Bettransm14 WITH(NOLOCK)
		WHERE refno IN (SELECT refno FROM @tmp_Bettrans)
		
	INSERT INTO @TopEvent (matchid, turnover)
	SELECT top 10 matchid, SUM(b.turnover)
	FROM #tmp_Bettransm bm 			
		INNER JOIN @tmp_Bettrans b ON bm.refno = b.refno
	GROUP BY bm.matchid
	ORDER BY SUM(b.turnover) DESC
	
	SELECT * 
	FROM
	(
		SELECT m.matchid, homeid, awayid, leagueid, t.turnover
		FROM bodb02.dbo.match m WITH(NOLOCK)
			INNER JOIN @TopEvent t ON m.matchid = t.matchid
		UNION 
		SELECT m.matchid, homeid, awayid, leagueid, t.turnover
		FROM bodb02.dbo.match14 m WITH(NOLOCK)
			INNER JOIN @TopEvent t ON m.matchid = t.matchid
	)r
	ORDER BY turnover DESC
		
	DROP INDEX ix_bettransm on #tmp_bettransm
	DROP TABLE #tmp_bettransm
	
GO
GRANT VIEW DEFINITION ON [dbo].[RMS_Monitor_Parlay_SelectionByTurnover_Currency_Event] TO [vnteam]
GO
GRANT EXECUTE ON [dbo].[RMS_Monitor_Parlay_SelectionByTurnover_Currency_Event] TO [bodbRMSNet]