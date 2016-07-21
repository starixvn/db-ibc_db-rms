ALTER PROCEDURE [dbo].[RMS_Rpt_ComboParlay_BetsStatisticsByIP_Sporttype]
	@fromdate		DATETIME,
	@IP				VARCHAR(30),
	@custid			INT,
	@sporttype		TINYINT
AS
	/*
		Created: Winnie
		Date: 2016-05-05
		Task: get bets list of customer by sport
		DB: DBRMS/bodb_RMS
		
		Parameter's Explanation:
			@sporttype = '1': soccer only
						= 2: others
		
	*/
BEGIN
	SET NOCOUNT ON 
	
	DECLARE @todate DATETIME
	SELECT @todate = @fromdate + '23:59:59'
	
	SELECT transid,
			refno,
			transdate,
			bettype,
			modds,
			odds,
			stake,
			statusid,
			status,			
			winlost - actual_stake as winlost,
			hdp1, hdp2, betteam, betcheck 
	FROM rmBettrans a WITH(NOLOCK)
	WHERE transdate between @fromdate and @todate
		AND custid = @custid
		AND IP = @IP
		AND ((@sporttype=1 AND transid2=1)OR(@sporttype=2 AND transid2<>1))
		
		
END 

GO
GRANT EXECUTE ON [dbo].[RMS_Rpt_ComboParlay_BetsStatisticsByIP_Sporttype] TO [bodbRMSNet]