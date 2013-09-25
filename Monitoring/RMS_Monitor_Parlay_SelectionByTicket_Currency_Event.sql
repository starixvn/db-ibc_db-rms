ALTER PROCEDURE [dbo].[RMS_Monitor_Parlay_SelectionByTicket_Currency_Event]
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
		Task:Get report top events by top tickets and currency
		DB: DBRMS/bodb_RMS
		
		Revisions:
			- 2013123@Johnson: move sp from DB054.bodb02 to DBRMS.bodb_RMS
			- 20130925@Johnson: call function f_RMS_strSplit instead of strSplit
		Parameter's Explanation
			- @sporttype = 0 : all sports
						= 1 : soccer only
						= 2 : Other sports
						= 3 : combined sports
			- @currency <> 0: currency to drill down
						= 0 : others currency not top currencies
			- @topcurrency: contain top currency by selection
							ex: '2,3,5,15,43'
			-- exec RMS_Monitor_Parlay_SelectionByTicket_Currency_Event 9,1,'2012-07-01',2,5,'',3760187352
	*/ 
SET NOCOUNT ON 
	DECLARE @tmp_Bettrans TABLE (refno bigint primary key, sporttype int , selection int,currency VARCHAR(20))
	DECLARE @TopEvent TABLE( matchid int, tickets int)
	DECLARE @matchid INT
	
	IF @bettype = 9 
		SELECT @matchid = 9
	ELSE IF @bettype = 29 
		SELECT @matchid = 29
		
	IF @currency <> 0
	BEGIN
		INSERT INTO @tmp_Bettrans (refno, sporttype, selection, currency)
		SELECT refno, liveawayscore, right(betcheck,len(betcheck)-1), CurrencyName
		FROM rmBettrans WITH(NOLOCK)
		WHERE matchid = @matchid
			AND statusid = 0
			AND winlostdate >= @winlostdate
			AND currency = @currency
			AND transid <= @max_transid
	END	
	ELSE
	BEGIN
		INSERT INTO @tmp_Bettrans (refno, sporttype, selection, currency)
		SELECT refno, liveawayscore, right(betcheck,len(betcheck)-1), CurrencyName
		FROM rmBettrans WITH(NOLOCK)
		WHERE matchid = @matchid
			AND statusid = 0
			AND winlostdate >= @winlostdate
			AND currency NOT IN (SELECT val FROM f_RMS_strSplit(@topcurrency,','))
			AND currency <> 20
			AND transid <= @max_transid
	END
	
	IF @sporttype <> 0
		DELETE @tmp_Bettrans WHERE sporttype <> @sporttype
	
	DELETE @tmp_Bettrans WHERE selection <> @selection
		
	INSERT INTO @TopEvent (matchid, tickets)
	SELECT top 10 matchid, count(1)
	FROM (
		SELECT bm.refno, bm.matchid
		FROM @tmp_Bettrans t
			INNER JOIN bodb02.dbo.bettransm bm WITH(NOLOCK) ON t.refno = bm.refno
		UNION 
		SELECT bm.refno, bm.matchid
		FROM @tmp_Bettrans t
			INNER JOIN bodb02.dbo.bettransm14 bm WITH(NOLOCK) ON t.refno = bm.refno
		) r		
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
GRANT VIEW DEFINITION ON [dbo].[RMS_Monitor_Parlay_SelectionByTicket_Currency_Event] TO [vnteam]
GO
GRANT EXECUTE ON [dbo].[RMS_Monitor_Parlay_SelectionByTicket_Currency_Event] TO [bodbRMSNet]

