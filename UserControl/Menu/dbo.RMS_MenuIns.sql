ALTER PROCEDURE [dbo].[RMS_MenuIns]
	@AdminID		INT,
	@MenuID			INT = 0 OUTPUT,
	@MenuName		NVARCHAR(50),
	@MenuDesc		NVARCHAR(100)= NULL,
	@URL			VARCHAR(500) = NULL,
	@FuncID			INT,
	@ParentID		INT = 0,
	@ParentName		NVARCHAR(50) = '',
	@DisplayOrder	INT,
	@Enabled		BIT = 1,
	@IP				VARCHAR(50),
	@ErrCode		INT  = 0 OUTPUT,
	@ErrMsg			VARCHAR(500) = '' OUTPUT
AS
	/*
		Created: Johnson
		Date: 2012-05-16
		Task: Edit menu info
		DB: DB054.bodb_RMS
		
		Revisions:
			-20120524@Elodie: No need to write log
		Parameter's Explanations:
	*/ 
SET NOCOUNT ON
	EXEC dbo.RMS_UserCheckPermission @UserID = @AdminID ,@FuncKey = 'ManageMenu', @ErrCode = @ErrCode OUTPUT, @ErrMsg = @ErrMsg OUTPUT
	
	IF @ErrCode > 0
		RETURN
	
	IF EXISTS (SELECT 1 FROM rmMenu WITH(NOLOCK) WHERE MenuName = @MenuName)
	BEGIN
		SELECT @ErrMsg = 'This name is not available',
				@ErrCode = 101
		RETURN
	END
	
	INSERT INTO [bodb_RMS].[dbo].[rmMenu]
           ([MenuName]
           ,[MenuDesc]
           ,[Url]
           ,[FuncID]
           ,[ParentID]
           ,[ParentName]
           ,[CreatedDate]
           ,[ModifiedDate]
           ,[DisplayOrder]
           ,[Creator]
           ,[enabled])
     VALUES(
			@MenuName, 
			@MenuDesc, 
			@URL, 
			@FuncID, 
			@ParentID, 
			@ParentName, 
			GETDATE(), 
			GETDATE(), 
			@DisplayOrder, 
			@AdminID, 
			@Enabled 
		)
	
	SELECT @MenuID = SCOPE_IDENTITY()
	
GO
GRANT VIEW DEFINITION ON [dbo].[RMS_MenuIns] TO [vnteam]
GO
GRANT EXECUTE ON [dbo].[RMS_MenuIns] TO [bodbRMSNet] 