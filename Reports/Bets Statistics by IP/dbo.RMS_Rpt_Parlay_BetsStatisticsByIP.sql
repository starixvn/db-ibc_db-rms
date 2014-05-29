 ALTER PROCEDURE [dbo].[RMS_Rpt_Parlay_BetsStatisticsByIP]
	@IP				varchar(30),
	@fromdate		datetime
 AS
	/*
		Created: Johnson
		Date: 2014-04-18
		Task: Get report customers bets by ip
		DB: DBRMS/bodb_RMS
	*/
BEGIN 
	SET NOCOUNT ON 
	
	declare @todate datetime

	set @todate = @fromdate + '23:59:59.999'
	
	SELECT custid
			,username
			,SUM(CASE WHEN liveawayscore = 1 THEN 1 ELSE 0 END) as cnt_soccer
			,SUM(CASE WHEN liveawayscore IN (2,3) THEN 1 ELSE 0 END) as cnt_others
	FROM rmBettrans WITH(NOLOCK)
	WHERE transdate between @fromdate and @todate
		AND IP = @IP
	GROUP BY custid, username
	
END
GO
GRANT EXECUTE ON [dbo].[RMS_Rpt_Parlay_BetsStatisticsByIP] TO [bodbRMSNet]