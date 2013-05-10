ALTER PROCEDURE [dbo].[RMS_Monitor_Parlay_SelectionByTurnover_Currency]
	@selection INT = 2,
	@sporttype INT = 0,
	@winlostdate DATETIME,
	@max_transid BIGINT
AS
	/*
		Created: Johnson
		Date: 2012-05-22
		Task: Get report top currency by selection and turnover 
		DB: DBRMS/bodb_RMS
				
		Revisions:
			- 20120807@Johnson: get currency id
			- 20130123@Johnson: move sp from DB054.bodb02 to DBRMS.bodb_RMS
		Parameter's Explanation:
			@sporttype = 0: All sports
						= 1: Soccer only
						= 2: Other sports
						= 3: Combined sports
	*/
SET NOCOUNT ON
----------------
	DECLARE @tmp_Bettrans TABLE (refno bigint primary key, selection int, sporttype int ,currency int, currencyName VARCHAR(20), turnover money)
	DECLARE @TopCurrency TABLE (rn int, currency int, currencyName VARCHAR(20),margin DECIMAL(5,2), turnover MONEY)
	DECLARE @TotalTurnover MONEY
	
	INSERT INTO @tmp_Bettrans (refno, selection, sporttype, currency, currencyName, turnover)
	SELECT refno, right(betcheck,len(betcheck)-1), liveawayscore, currency, CurrencyName, actual_stake*actualrate
	FROM rmBettrans WITH(NOLOCK)
	WHERE matchid = 9
		AND statusid = 0
		AND winlostdate >= @winlostdate
		AND currency <> 20
		AND transid <= @max_transid
	
	IF @sporttype <> 0
		DELETE @tmp_Bettrans WHERE sporttype <> @sporttype
	
	DELETE @tmp_Bettrans WHERE selection <> @selection
		
	SELECT @totalTurnover = ISNULL(NULLIF(SUM(turnover),0),1) FROM @tmp_Bettrans
	
	INSERT INTO @TopCurrency (rn, currency, currencyName ,turnover, margin)
	SELECT top 5 row_number () over (order by  sum(turnover) DESC) rn, currency, currencyName, sum(turnover), sum(turnover)*100.0/@totalTurnover
	FROM @tmp_Bettrans
	GROUP BY currency, currencyName
	
	INSERT INTO @TopCurrency(rn, currency, currencyName, turnover, margin)
	SELECT 6, 0, 'Others', ISNULL(sum(turnover),0), ISNULL(sum(turnover),0)*100.0/@totalTurnover
	FROM @tmp_Bettrans
	WHERE currency NOT IN (SELECT currency FROM @TopCurrency)
	
	SELECT * FROM @TopCurrency
	ORDER BY rn ASC

GO
GRANT EXECUTE ON [dbo].[RMS_Monitor_Parlay_SelectionByTurnover_Currency] TO [bodbRMSNet]
GO
GRANT VIEW DEFINITION ON [dbo].[RMS_Monitor_Parlay_SelectionByTurnover_Currency] TO [vnteam]