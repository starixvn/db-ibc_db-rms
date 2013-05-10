ALTER PROCEDURE [dbo].[RMS_MenuUpdStatus]
	@AdminID	INT,
	@MenuID		INT,
	@Enabled	BIT,
	@IP			VARCHAR(50),
	@ErrCode	INT = 0 OUTPUT,
	@ErrMsg		VARCHAR(500) = '' OUTPUT
AS
	/*
		Created: Johnson
		Date: 2012-05-18
		Task: Update status of menu
		DB: DB054.bodb_RMS
		
		Revisions:
			-20120524@Elodie: No need to write log
		Parameter's Explanation:
	*/
SET NOCOUNT ON
	EXEC dbo.RMS_UserCheckPermission @UserID = @AdminID ,@FuncKey = 'ManageMenu', @ErrCode = @ErrCode OUTPUT, @ErrMsg = @ErrMsg OUTPUT
	
	IF @ErrCode > 0
		RETURN
	
	DECLARE @db_Enabled BIT
	
	SELECT @db_Enabled = enabled FROM rmMenu WITH(NOLOCK) WHERE MenuID = @MenuID
	
	IF @@ROWCOUNT = 0 OR @db_enabled = @enabled
		RETURN
		
	UPDATE rmMenu WITH(UPDLOCK,ROWLOCK)
	SET enabled = @enabled
	WHERE MenuID = @MenuID
	
GO
GRANT VIEW DEFINITION ON [dbo].[RMS_MenuUpdStatus] TO [vnteam]
GO
GRANT EXECUTE ON [dbo].[RMS_MenuUpdStatus] TO [bodbRMSNet]