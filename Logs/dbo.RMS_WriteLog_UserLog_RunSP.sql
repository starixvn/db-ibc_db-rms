 ALTER PROCEDURE [dbo].[RMS_WriteLog_UserLog_RunSP]
	@UserID			INT,
	@CustID			INT = 0,
	@ActionID		INT = NULL,
	@TrackingValue	VARCHAR(MAX) = NULL,
	@TrackingValue2 VARCHAR(MAX) = NULL,
	@Duration		INT	= NULL
AS
	/*
		Created: Johnson
		Date: 2012-05-09
		Task: write log data
		DB: DBLOG.bodb_CustomerLog
		
		Revisions:
			- 20120524@Elodie: remove @SPName, @TrackingValue2 parameters
			- 20121029@Johnson: Add parameter @TrackingValue2
		Parameter's Explanation:
	*/
SET NOCOUNT ON
	
	INSERT INTO [bodb_CustomerLog].[dbo].[rmUserLog_RunSP]
           ([UserID]  
           ,[Logdate]
           ,[CustID]
           ,[ActionID]
           ,[TrackingValue]
           ,[TrackingValue2]
           ,[Duration])
     VALUES( @UserID, GETDATE(), @CustID, @ActionID, @TrackingValue, @TrackingValue2, @Duration)


GO
GRANT VIEW DEFINITION ON [dbo].[RMS_WriteLog_UserLog_RunSP] TO [vnteam]
GO
GRANT EXECUTE ON [dbo].[RMS_WriteLog_UserLog_RunSP] TO [bodbRMSNet]