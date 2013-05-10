ALTER PROCEDURE [dbo].[RMS_UserLogout]
	@on_userid INT,
	@username  NVARCHAR(50)= NULL
AS
	/*
		Created: Johnson
		Date: 2012-05-07
		Task: admin log out RMS
		DB: DB054.bodb_RMS
		
		Revsisons:
		
		Parameter's Explanation:
	*/ 
SET NOCOUNT ON 
	
	SET NOCOUNT ON
	DECLARE @Begin		DATETIME
	DECLARE @End		DATETIME
	DECLARE @Duration	INT

	SET @Begin = GETDATE()
	
	--Write log to record user logout
	Declare @CustID int, @LoginIP varchar(15),   
			@LogData nvarchar(200)
	
	SELECT	@CustID = 0, @LoginIP = '127.0.0.0'  
	
	SELECT @CustID = custid, @LoginIP = IP 
	FROM rmOn_User WITH (nolock) WHERE on_userid = @On_UserID
		
	DELETE FROM rmOn_user WITH(ROWLOCK) WHERE on_userid = @on_userid
	
	SELECT @LogData =  'Admin:' + CASE WHEN ISNULL(@UserName,'') = '' THEN CAST(@custid AS VARCHAR(30)) ELSE @Username END + ' Logout Success'
	
	SET @End = GETDATE()
	SET @Duration = DATEDIFF(millisecond,@Begin,@End)

	EXEC DBLOG.bodb_customerlog.dbo.RMS_WriteLog_UserLog_Login 
		 @UserID = @CustID, 		
		 @LoginIP = @LoginIP,
		 @ActionID = 10201,	 
		 @Doing = @LogData,
		 @Duration = @Duration
		 
GO 
GRANT VIEW DEFINITION ON [RMS_UserLogout] TO [vnteam]
GO
GRANT EXECUTE ON [RMS_UserLogout] TO [bodbRMSNet]