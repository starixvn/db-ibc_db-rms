ALTER PROCEDURE [dbo].[RMS_FunctionUpd]
	@AdminID	INT,
	@FuncID		INT,
	@FuncName	VARCHAR(50),
	@FuncDesc	VARCHAR(100),
	@ParentID	INT,
	@ParentName VARCHAR(50),
	@DisplayOrder INT,
	@IP			VARCHAR(50),
	@ErrCode	INT = 0 OUTPUT,
	@ErrMsg		VARCHAR(500) = '' OUTPUT	
AS
	/*
		Created: Johnson
		Date: 2012-05-16
		Task: Update function info
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
	
	EXEC dbo.RMS_UserCheckPermission @UserID = @AdminID ,@FuncKey = 'ManageFunction', @ErrCode = @ErrCode OUTPUT, @ErrMsg = @ErrMsg OUTPUT
	
	IF @ErrCode > 0
		RETURN

	DECLARE @db_FuncName	VARCHAR(50),
			@db_FuncDesc	VARCHAR(100),
			@db_ParentID	INT,
			@db_ParentName	VARCHAR(50),
			@db_DisplayOrder INT
	
	SELECT @db_FuncName	= FuncName,
			@db_ParentID = ParentID,
			@db_ParentName = ParentName,
			@db_DisplayOrder = DisplayOrder,
			@db_FuncDesc = FuncDesc
	FROM rmFunction WITH(NOLOCK)
	WHERE FuncID = @FuncID
	
	IF @@ROWCOUNT = 0
	BEGIN
		SELECT @ErrMsg = 'This function not exists',
			@ErrCode = 101
		RETURN
	END
	
	IF @db_FuncName	= @FuncName AND
		@db_ParentID = @ParentID AND
		@db_ParentName = @ParentName AND
		@db_DisplayOrder = @DisplayOrder AND
		@db_FuncDesc = @FuncDesc
	RETURN
	
	UPDATE rmFunction WITH(UPDLOCK,ROWLOCK)
	SET FuncName	= @FuncName,
		ParentID = @ParentID,
		ParentName = @ParentName,
		DisplayOrder = @DisplayOrder,
		ModifiedDate = current_timestamp,
		FuncDesc = @FuncDesc
	WHERE FuncID = @FuncID
	
	IF @db_FuncName <> @FuncName
	BEGIN
		UPDATE rmFunction WITH(UPDLOCK,ROWLOCK)
		SET ParentName = @FuncName
		WHERE ParentID = @FuncID
	END
	
	DECLARE @LogData NVARCHAR(500)
	SELECT @LogData = '<RMS_FunctionUpd FuncNameOld="' + COALESCE(@db_FuncName, SPACE(1)) + '" ' +
						'FuncNameNew="' + COALESCE(@FuncName, SPACE(1)) + '" ' +
						'FuncDescNew="' + COALESCE(@FuncDesc, SPACE(1)) + '" ' +
						'FuncDescOld="' + COALESCE(@db_FuncDesc, SPACE(1)) + '" ' +
						'ParentNameOld="' + COALESCE(@db_ParentName, SPACE(1)) + '" ' +
						'ParentNameNew="' + COALESCE(@ParentName, SPACE(1)) + '" ' +
						'DisplayOrderOld="' + COALESCE(CONVERT(VARCHAR(10),@db_DisplayOrder), SPACE(1)) + '" ' +
						'DisplayOrderNew="' + COALESCE(CONVERT(VARCHAR(10),@DisplayOrder), SPACE(1)) + '" ' +
						'IP="'		 + COALESCE(@IP, SPACE(1)) + '" />'

	SET @endRun = GETDATE()  
	SET @duration  = DATEDIFF (MILLISECOND,@startRun,@endRun)   

	EXEC DBLOG.bodb_CustomerLog.[dbo].[RMS_WriteLog_UserLog_UserControl]
			@custID = @FuncID,
			@Doing = @LogData,
			@userid = @AdminID,
			@TypeID = 2,
			@actionid = 10101,
			@duration = @duration  
	
GO
GRANT VIEW DEFINITION ON [dbo].[RMS_FunctionUpd] TO [vnteam]
GO
GRANT EXECUTE ON [dbo].[RMS_FunctionUpd] TO [bodbRMSNet]