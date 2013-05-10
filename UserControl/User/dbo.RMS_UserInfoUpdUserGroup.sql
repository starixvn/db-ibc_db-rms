 ALTER PROCEDURE [dbo].[RMS_UserInfoUpdUserGroup]
	@AdminID	INT,
	@CustID		INT,
	@GroupID	INT,
	@IP			VARCHAR(50),
	@ErrCode	INT = 0 OUTPUT,
	@ErrMsg		VARCHAR(500) = '' OUTPUT
AS
	/*
		Created: Johnson
		Date: 2012-05-11
		Task: Update user's group
		DB: DBRMS/bodb_RMS
		
		Revisions:
			- 20120523@Elodie: Write log
			- 20130313@Johnson: Fix format log by xml format
		Parameter's Explanation:
	*/
SET NOCOUNT ON
	DECLARE @startRun datetime  
		,@endRun datetime  
		,@duration int		
	
	SET @startRun=GETDATE()
	
	EXEC dbo.RMS_UserCheckPermission @UserID = @AdminID ,@FuncKey = 'ManageUser', @ErrCode = @ErrCode OUTPUT, @ErrMsg = @ErrMsg OUTPUT
	
	IF @ErrCode > 0
		RETURN
	
	DECLARE @db_groupid INT
	
	SELECT @db_groupid = groupid FROM rmUserInfo WITH(NOLOCK) WHERE UserID = @CustID
	
	IF @@ROWCOUNT = 0 OR @GroupID = @db_groupID
		RETURN
	
	UPDATE rmUserInfo WITH(UPDLOCK,ROWLOCK) 
	SET GroupID = @GroupID
	WHERE UserID = @CustID
	
	DECLARE @LogData NVARCHAR(500)
    SELECT @LogData =	'<RMS_UserInfoUpdUserGroup GroupIDOld="' + COALESCE(CONVERT(VARCHAR(10),@db_groupid),SPACE(1)) + '" ' +						
						'GroupIDNew="' + COALESCE(CONVERT(VARCHAR(10),@GroupID),SPACE(1)) + '" ' +						
						'IP="' + COALESCE(@IP,SPACE(1)) + '" />'

    SET @endRun = GETDATE();
    SET @Duration = DATEDIFF(millisecond, @startRun, @endRun);

    EXEC DBLOG.bodb_CustomerLog.[dbo].[RMS_WriteLog_UserLog_UserControl] 
		@custID = @CustID, 
		@Doing = @LogData, 
		@userid = @AdminID, 
		@TypeID = 1, 
		@actionid = 10005, 
		@duration = @Duration
	
GO
GRANT VIEW DEFINITION ON [dbo].[RMS_UserInfoUpdUserGroup] TO [vnteam]
GO
GRANT EXECUTE ON [dbo].[RMS_UserInfoUpdUserGroup] TO [bodbRMSNet]