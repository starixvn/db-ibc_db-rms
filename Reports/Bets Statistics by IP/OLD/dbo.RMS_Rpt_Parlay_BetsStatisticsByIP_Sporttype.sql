ALTER PROCEDURE [dbo].[RMS_Rpt_Parlay_BetsStatisticsByIP_Sporttype]
	@fromdate		DATETIME,
	@IP				VARCHAR(39),
	@custid			INT,
	@sporttype		INT
AS
	/*
		Created: Johnson
		Date: 2014-04-18
		Task: get bets list of customer by sport
		DB: DBRMS/bodb_RMS
		
		Parameter's Explanation:
			@sporttype = '1': soccer only
						= 2: others
		Revisions:	
		- 20211001@Danny: Change dataType to support IPv6 [RedmineID: #162348]
		
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
			combo,
			winlost - actual_stake as winlost	
	FROM rmBettrans WITH(NOLOCK)
	WHERE transdate between @fromdate and @todate
		AND custid = @custid
		AND IP = @IP
		AND 1 = CASE when @sporttype = 1 and liveawayscore = 1 then 1
					when @sporttype = 2 AND liveawayscore in (2,3) THEN 1
					else 0 END
		
END 
GO
GRANT EXECUTE ON [dbo].[RMS_Rpt_Parlay_BetsStatisticsByIP_Sporttype] TO [bodbRMSNet]