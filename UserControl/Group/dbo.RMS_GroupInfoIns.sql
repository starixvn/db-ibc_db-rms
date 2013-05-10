ALTER PROCEDURE [dbo].[RMS_GroupInfoIns]
	@AdminID		INT,
	@GroupName		VARCHAR(100),
	@Description	VARCHAR(200) = NULL,
	@IP				VARCHAR(50),
	@GroupID		INT = 0 OUTPUT,
	@ErrCode		INT = 0 OUTPUT,
	@ErrMsg			VARCHAR(500) = '' OUTPUT
AS
	/*
		Created: Johnson
		Date: 2012-05-10
		Task: Create new group
		DB: DBRMS/bodb_RMS
		
		Revisions:
			- 20120523@Elodie: Write log
			- 20130313@Johnson: Fix format log by xml format
		Parameter's Explanation:
	*/
SET NOCOUNT ON

	DECLARE @startRun datetime,
			@endRun datetime,
			@duration int
	
	SET @startRun=GETDATE()
	
	EXEC dbo.RMS_UserCheckPermission @UserID = @AdminID ,@FuncKey = 'ManageGroup', @ErrCode = @ErrCode OUTPUT, @ErrMsg = @ErrMsg OUTPUT
	
	IF @ErrCode > 0
		RETURN
	
	IF EXISTS (SELECT 1 FROM rmGroup WITH(NOLOCK) WHERE GroupName = @GroupName)
	BEGIN
		SELECT @ErrMsg = 'This group''s name is used.',
				@ErrCode = 100
		RETURN
	END
	
	INSERT INTO rmGroup (GroupName, Description, CreatedDate, Creator)
	VALUES (@GroupName, @Description, GETDATE(), @AdminID)
	
	SELECT @GroupID = SCOPE_IDENTITY()
	
	--Initial group policy
	INSERT INTO rmGroupPolicy (GroupID, FuncID, Policy)
	SELECT @GroupID, funcid, 0
	FROM rmFunction WITH(NOLOCK)	
	
	DECLARE @LogData nvarchar(500)
	SELECT @LogData = '<RMS_GroupInfoIns GroupName="' + COALESCE(@GroupName,SPACE(1)) + '" ' +
						'Description="' + COALESCE(@Description,SPACE(1)) + '" ' +
						'IP="' + COALESCE(@IP,SPACE(1)) + '" />'

	SET @endRun = getdate()  
	SET @duration  = datediff (millisecond,@startRun,@endRun)   

	EXEC DBLOG.bodb_CustomerLog.[dbo].[RMS_WriteLog_UserLog_UserControl]
			@custID = @GroupID,
			@Doing = @LogData,
			@userid = @AdminID,
			@TypeID = 0,
			@actionid = 10000,
			@duration = @duration  

GO 
GRANT VIEW DEFINITION ON [dbo].[RMS_GroupInfoIns] TO [vnteam]
GO
GRANT EXECUTE ON [dbo].[RMS_GroupInfoIns] TO [bodbRMSNet]