ALTER PROCEDURE [dbo].[RMS_SelBalanceUpDay]
AS
	/*
		Created: Johnson
		Date: 2012-11-08
		Task: Get move bets day and balance up day for RMS
		DB: DB054.bodb_RMS
		
		Revisions:
		
		Parameter's Explanation: 
	*/ 
SET NOCOUNT ON
	DECLARE @BalanceUpDay smalldatetime, @MoveBetsDay smalldatetime
	SELECT 
		TOP 1 @BalanceUpDay = winlostdate
	FROM bodb02.dbo.Bettrans WITH(NOLOCK)
	WHERE bettype = 20000 and matchid = 0	and custid = 3
	
	SELECT    
		@MoveBetsDay = MAX(eventdate)  
	FROM bodb02.dbo.match14 WITH(NOLOCK)  
	

	select @BalanceUpDay as BalanceUpDay, @MoveBetsDay as MoveBetsDay


GO
GRANT EXECUTE ON [dbo].[RMS_SelBalanceUpDay] TO [bodbRMSNet]