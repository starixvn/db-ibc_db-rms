 ALTER PROCEDURE [dbo].[RMS_Rpt_Parlay_SelMinTransdate]
 AS
	/*
		Created: Johnson
		Date: 2014-05-27
		Task: Get min transdate from rmBettrans
		DB: DBRMS/bodb_RMS
	*/
BEGIN
	SET NOCOUNT ON
	
	SELECT MIN(transdate) as transdate_min from rmBettrans WITH(NOLOCK)
	
END
GO

GRANT EXECUTE ON [dbo].[RMS_Rpt_Parlay_SelMinTransdate] TO [bodbRMSNet]
