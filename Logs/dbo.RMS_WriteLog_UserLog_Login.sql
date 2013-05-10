 ALTER PROCEDURE [dbo].[RMS_WriteLog_UserLog_Login]
	@UserID INT,  
    @LoginIP VARCHAR(50)='', 
	@ActionID int = 0, 
    @DomainName NVARCHAR(253) = NULL,
    @Doing VARCHAR(300),
    @BrowserName NVARCHAR(255) = NULL,
    @Platform NVARCHAR(255) = NULL,
    @CountryCode VARCHAR(64) = NULL,
    @Duration INT = NULL	
 AS
	/*
		Created: Johnson
		Date: 2012-05-04
		Task: Write log admin login RMS
		DB: DBLog.bodb_CustomerLog
		
		Revisions:
			-20120524@Elodie: Add @ActionID parameter
		Parameter's Explanations:
	*/
SET NOCOUNT ON

	INSERT INTO [dbo].[rmUserLog_Login]
           ([UserID]
           ,[IP]
           ,[LogDate]
		   ,[ActionID]
           ,[Doing]
           ,[DomainName]
           ,[BrowserName]
           ,[Platform]
           ,[CountryCode]
           ,[Duration])
     VALUES
           (@UserID,@LoginIP,GETDATE(),@ActionID,@Doing,@DomainName,@BrowserName,@Platform,@CountryCode,@Duration)

GO
GRANT VIEW DEFINITION ON [dbo].[RMS_WriteLog_UserLog_Login] TO [vnteam]
GO
GRANT EXECUTE ON [dbo].[RMS_WriteLog_UserLog_Login] TO [bodbRMSNet]