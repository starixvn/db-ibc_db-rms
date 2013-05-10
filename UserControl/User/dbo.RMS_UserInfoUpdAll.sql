 ALTER PROCEDURE [dbo].[RMS_UserInfoUpdAll]
	@AdminID	INT,
	@CustID		INT,		
	@firstname	NVARCHAR(50),
	@lastname	NVARCHAR(50),	
	@GroupID	INT,	
	@IP			VARCHAR(50),
	@ErrCode	INT = 0 OUTPUT,
	@ErrMsg		VARCHAR(500) = '' OUTPUT
AS
	/*
		Created: Johnson
		Date: 2012-05-11
		Task: Update user info 
		DB: DBTXN/bodb02
		
		Revsisions:
			- 20120523@Elodie: Write log
			- 20130121@Johnson: change linked server DB054 to DBRMS
			- 20130313@Johnson: fix format log by xml format
		Parameter's Explanation:
	*/
SET NOCOUNT ON

	DECLARE @startRun datetime  
		,@endRun datetime  
		,@duration int		
	
	SET @startRun=GETDATE()
	
	EXEC DBRMS.bodb_RMS.dbo.RMS_UserCheckPermission @UserID = @AdminID ,@FuncKey = 'ManageUser', @ErrCode = @ErrCode OUTPUT, @ErrMsg = @ErrMsg OUTPUT
	
	IF @ErrCode > 0
		RETURN
	
	EXEC DBRMS.bodb_RMS.dbo.RMS_UserInfoUpdUserGroup 
		@AdminID = @AdminID,
		@CustID	 = @CustID,
		@GroupID = @GroupID,
		@IP		 = @IP,
		@ErrCode = @ErrCode OUTPUT,
		@ErrMsg	 = @ErrMsg OUTPUT
	
	IF @ErrCode > 0
		RETURN
		
	DECLARE @db_firstname	NVARCHAR(50),			
			@db_lastname	NVARCHAR(50)
	
	SELECT @db_firstname = firstname, 
		@db_lastname = lastname
	FROM Customer WITH(NOLOCK)
	WHERE CustID = @CustID
	
	IF @@ROWCOUNT = 0 
		RETURN	
	
	IF @db_firstname = @firstname AND @db_lastname = @lastname
		RETURN
		
	UPDATE Customer WITH(UPDLOCK,ROWLOCK)
	SET firstname = @firstname,
		lastname = @lastname 
	WHERE CustID = @CustID
	
	DECLARE @LogData NVARCHAR(MAX)
	SELECT @LogData = '<RMS_UserInfoUpdAll FirstNameOld="' + COALESCE(@db_firstname,SPACE(1)) + '" ' +
						'FirstNameNew="' + COALESCE(@firstname,SPACE(1)) + '" ' +
						'LastNameOld="' + COALESCE(@db_lastname,SPACE(1)) + '" ' +
						'LastNameNew="' + COALESCE(@lastname,SPACE(1)) + '" ' +
						'IP="' + COALESCE(@IP,SPACE(1)) + '" />'
				
	SET @endRun = GETDATE()  
	SET @duration  = DATEDIFF (MILLISECOND,@startRun,@endRun)   
	
	BEGIN TRY
		EXEC DBLOG.bodb_CustomerLog.[dbo].[RMS_WriteLog_UserLog_UserControl] 
			@custID = @CustID, 
			@Doing = @LogData, 
			@userid = @AdminID, 
			@TypeID = 1, 
			@actionid = 10007, 
			@duration = @duration
	END TRY
	BEGIN CATCH
		SELECT @LogData = '<RMS_UserInfoUpdAll FirstNameOld="' + COALESCE(@db_firstname,SPACE(1)) + '" ' +
						'FirstNameNew="' + COALESCE(@firstname,SPACE(1)) + '" ' +
						'LastNameOld="' + COALESCE(@db_lastname,SPACE(1)) + '" ' +
						'LastNameNew="' + COALESCE(@lastname,SPACE(1)) + '" ' +
						'IP="' + COALESCE(@IP,SPACE(1)) + '" ' + 
						'ErrMsg="' + COALESCE(ERROR_MESSAGE(),SPACE(1)) + '" />'
						
		EXEC bodb_CustomerLog.[dbo].[RMS_WriteLog_UserLog_UserControl] 
			@custID = @CustID, 
			@Doing = @LogData, 
			@userid = @AdminID, 
			@TypeID = 1, 
			@actionid = 10007, 
			@duration = @duration
	END CATCH
GO 
GRANT VIEW DEFINITION ON [dbo].[RMS_UserInfoUpdAll] TO [vnteam]
GO 
GRANT EXECUTE ON [dbo].[RMS_UserInfoUpdAll] TO [bodbRMSNet]