ALTER PROCEDURE [dbo].[RMS_Rpt_ComboParlay_BetsStatisticsByIP_Sporttype]
	@fromdate		DATETIME,
	@IP				VARCHAR(30),
	@custid			INT,
	@sporttype		VARCHAR(100)
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
	DECLARE @tmpSport TABLE (sporttype int)
	SELECT @todate = @fromdate + '23:59:59'
	
	INSERT INTO @tmpSport (sporttype)
	SELECT val
	FROM f_RMS_strSplit (@sporttype,',')
	
	IF EXISTS (SELECT TOP 1 1 FROM @tmpSport WHERE sporttype=-2)
	BEGIN
	INSERT INTO @tmpSport
	SELECT SportType FROM bodb02.dbo.Sports(NOLOCK) WHERE SportType NOT IN (1,2,3,4,5,6,7,8,9,11,43)
	END
	
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
	INNER JOIN @tmpSport b ON a.transid2=b.sporttype
	WHERE transdate between @fromdate and @todate
		AND custid = @custid
		AND IP = @IP
		
		
END 

GO
GRANT EXECUTE ON [dbo].[RMS_Rpt_ComboParlay_BetsStatisticsByIP_Sporttype] TO [bodbRMSNet]