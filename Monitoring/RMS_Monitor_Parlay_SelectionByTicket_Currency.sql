ALTER PROCEDURE [dbo].[RMS_Monitor_Parlay_SelectionbyTicket_Currency]
	@selection INT = 2,
	@sporttype INT = 0,
	@winlostdate DATETIME,
	@max_transid BIGINT = 0
AS
	/*
		Created: Johnson
		Date:2012-05-22
		Task: Get report top currency by selection and sport type
		DB: DB054.bodb02
			
		Revisions:
			- 20120807@Johnson: get currency id
			- 20130123@Johnson: move sp from DB054.bodb02 to DBRMS.bodb_RMS
		Parameter's Explanation:
			- @sporttype = 0 : all sports
						= 1 : soccer only
						= 2 : Other sports
						= 3 : combined sports
	*/
SET NOCOUNT ON
----------------
	DECLARE @tmp_Bettrans TABLE (refno bigint primary key, sporttype int ,selection int, currency int, currencyName VARCHAR(20))
	DECLARE @tmp_Bettransm TABLE (refno bigint primary key)
	DECLARE @TopCurrency TABLE (rn int, currency int, currencyName VARCHAR(20),margin DECIMAL(5,2), NoTickets INT)
	DECLARE @TotalTickets INT
	
	INSERT INTO @tmp_Bettrans (refno, sporttype, selection, currency, currencyName)
	SELECT refno, liveawayscore, right(betcheck,len(betcheck)-1), currency, CurrencyName
	FROM rmBettrans WITH(NOLOCK)
	WHERE bettype = 9
		AND matchid = 9
		AND statusid = 0
		AND winlostdate >= @winlostdate
		AND currency <> 20
		AND transid <= @max_transid
	
	IF @sporttype <> 0
		DELETE @tmp_Bettrans WHERE sporttype <> @sporttype
	
	DELETE @tmp_Bettrans WHERE selection <> @selection

	SELECT @totalTickets = ISNULL(NULLIF(COUNT(1),0),1) FROM @tmp_Bettrans
	
	INSERT INTO @TopCurrency (rn, currency, currencyName, NoTickets, margin)
	SELECT top 5 row_number () over (order by count(1) DESC), currency, currencyName, count(1) NoTickets, count(1)*100.0/@totalTickets
	FROM @tmp_Bettrans
	GROUP BY currency, currencyName
		
	INSERT INTO @TopCurrency(rn,currency, currencyName, NoTickets, margin)
	SELECT 6, 0, 'Others', count(1), count(1)*100.0/@totalTickets
	FROM @tmp_Bettrans
	WHERE currency NOT IN (SELECT currency FROM @TopCurrency)
	
		
	SELECT * FROM @TopCurrency
	ORDER BY rn ASC
GO
GRANT EXECUTE ON [dbo].[RMS_Monitor_Parlay_SelectionbyTicket_Currency] TO [bodbRMSNet]
GO
GRANT VIEW DEFINITION ON [dbo].[RMS_Monitor_Parlay_SelectionbyTicket_Currency] TO [vnteam]