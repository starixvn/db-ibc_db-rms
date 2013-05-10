 ALTER PROCEDURE [dbo].[RMS_UserInfoAddExisting]
	@AdminID	INT,
	@Username	VARCHAR(50),
	@custid		INT = 0 OUTPUT,
	@groupid	INT,
	@IP			VARCHAR(50),
	@ErrCode	INT = 0 OUTPUT,
	@ErrMsg		VARCHAR(500) = '' OUTPUT
AS
/*
	Created: Johnson
	Date: 2012-05-14
	Task: Add RMS's user from IBC
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
	DECLARE @roleid INT
	
	SELECT @custid = custid, @roleid = roleid
	FROM bodb02.dbo.Customer WITH(NOLOCK) 
	WHERE username = @username
	
	IF ISNULL(@custid,0) = 0
	BEGIN
		SELECT @ErrMsg = 'Invalid username.',
				@ErrCode = 100
		RETURN
	END
	
	IF @roleid < 5
	BEGIN
		SELECT @ErrMsg = 'This user not admin',
			@ErrCode = 101
		RETURN
	END
	
	IF EXISTS (SELECT 1 FROM rmUserInfo WITH(NOLOCK) WHERE UserID = @CustID)
	BEGIN
		SELECT @ErrMsg = 'This user exists in system',
				@ErrCode = 102
		RETURN		
	END
	
	IF NOT EXISTS (SELECT 1 FROM rmGroup WITH(NOLOCK) WHERE GroupID = @GroupID)
	BEGIN
		SELECT @ErrMsg = 'Invalid group',
				@ErrCode = 103
		RETURN
	END
	
	INSERT INTO rmUserInfo (UserID, GroupID, enabled, creator, CreatedDate)
	VALUES (@custid, @groupid, 1, @AdminID, current_timestamp)
	
	--initial user policy
	INSERT INTO rmUserPolicy (UserID, FuncID, Policy)
	SELECT @custid, funcid, 0
	FROM rmFunction WITH(NOLOCK)
	
	DECLARE @LogData NVARCHAR(500)
	SELECT @LogData = '<RMS_UserInfoAddExisting UserName="' + COALESCE(@UserName, SPACE(1)) + '" ' +
						'GroupID="' + COALESCE(CONVERT(VARCHAR(10),@GroupID),SPACE(1)) + '" ' +						
						'IP="' + COALESCE(@IP,SPACE(1)) + '" />'

	SET @endRun = GETDATE()  
	SET @duration  = DATEDIFF (MILLISECOND,@startRun,@endRun)   

	EXEC DBLOG.bodb_CustomerLog.[dbo].[RMS_WriteLog_UserLog_UserControl] 
		@custID = @custid, 
		@Doing = @LogData, 
		@userid = @AdminID, 
		@TypeID = 1, 
		@actionid = 10004, 
		@duration = @duration
	
GO
GRANT VIEW DEFINITION ON [dbo].[RMS_UserInfoAddExisting] TO [vnteam]
GO
GRANT EXECUTE ON [dbo].[RMS_UserInfoAddExisting] TO [bodbRMSNet]