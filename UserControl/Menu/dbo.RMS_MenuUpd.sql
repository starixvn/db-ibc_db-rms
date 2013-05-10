ALTER PROCEDURE [dbo].[RMS_MenuUpd]
	@AdminID		INT,
	@MenuID			INT,
	@MenuName		NVARCHAR(50),
	@MenuDesc		NVARCHAR(100)= NULL,
	@URL			VARCHAR(500) = NULL,
	@FuncID			INT,
	@ParentID		INT,
	@ParentName		NVARCHAR(50),
	@DisplayOrder	INT,	
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
	
	IF EXISTS (SELECT 1 FROM rmMenu WITH(NOLOCK) WHERE MenuID <> @MenuID AND MenuName = @MenuName)
	BEGIN
		SELECT @ErrMsg = 'This menu''s name is used',
			@ErrCode = 101
		RETURN
	END
	
	DECLARE @db_MenuName	NVARCHAR(50),
			@db_MenuDesc	NVARCHAR(100),
			@db_URL			VARCHAR(500),
			@db_FuncID		INT,
			@db_ParentID	INT,
			@db_ParentName	NVARCHAR(50),
			@db_DisplayOrder INT,
			@db_Enabled		BIT
	
	SELECT @db_MenuName	= MenuName,
			@db_MenuDesc = MenuDesc,
			@db_URL		 = url,
			@db_FuncID	 = funcID,
			@db_ParentID = parentID,
			@db_ParentName = parentName,
			@db_DisplayOrder = DisplayOrder
	FROM rmMenu WITH(NOLOCK)
	WHERE MenuID = @MenuID
	
	IF 	@db_MenuName	= @MenuName AND
		@db_MenuDesc = @MenuDesc AND
		@db_URL		 = @url AND
		@db_FuncID	 = @funcID AND
		@db_ParentID = @parentID AND
		@db_ParentName = @parentName AND
		@db_DisplayOrder = @DisplayOrder
	RETURN
	
	UPDATE rmMenu WITH(UPDLOCK,ROWLOCK)
	SET MenuName = @MenuName,
		MenuDesc = @MenuDesc,
		URL		 = @url,
		FuncID	 = @funcID,
		ParentID = @parentID,
		ParentName = @parentName,
		DisplayOrder = @DisplayOrder,
		ModifiedDate = current_timestamp
	WHERE MenuID = @MenuID
	
GO
GRANT VIEW DEFINITION ON [dbo].[RMS_MenuUpd] TO [vnteam]
GO
GRANT EXECUTE ON [dbo].[RMS_MenuUpd] TO [bodbRMSNet]