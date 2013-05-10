ALTER PROCEDURE [dbo].[RMS_UserCheckPermission]
	@UserID		INT,
	@FuncID		INT = NULL,
	@FuncKey	VARCHAR(100),
	@Language	VARCHAR(3) = 'E',
	@ErrCode	INT = 0 OUTPUT,
	@ErrMsg		VARCHAR(500) = '' OUTPUT
AS
	/*
		Created: Johnson
		Date: 2012-05-09
		Task: Check user's permission on function
		DB: DB054.bodb_RMS
		
		Revisions:
		
		Parameter's Explanation:
	*/
SET NOCOUNT ON

	IF @funcid IS NULL
		SELECT @funcid = FuncID FROM rmFunction WITH(NOLOCK) WHERE FuncKey = @FuncKey
	
	IF NOT EXISTS (SELECT 1 FROM rmUserInfo WITH(NOLOCK) WHERE UserID = @UserID AND enabled = 1)
	BEGIN
		SELECT @ErrMsg = 'This user not have permission to access RMS',
			@ErrCode = 100
		RETURN
	END
	
	DECLARE @isAllowed TINYINT
	
	SELECT @isAllowed = CASE WHEN ISNULL(u.Policy,0) >= ISNULL(g.Policy,0) THEN ISNULL(u.Policy,0) ELSE ISNULL(g.Policy,0) END
	FROM 
	(
		SELECT FuncID, Policy
		FROM rmUserPolicy WITH(NOLOCK)
		WHERE UserID =@UserID AND FuncID = @FuncID
	) u
	FULL OUTER JOIN
	(
		SELECT FuncID, Policy
		FROM rmGroupPolicy WITH(NOLOCK) 
		WHERE groupID = (SELECT groupID FROM rmUserInfo WITH(NOLOCK) WHERE UserID =@UserID)
			AND FuncID = @FuncID 
	) g ON u.FuncID = g.FuncID 
	
	IF ISNULL(@isAllowed,0) < 2
	BEGIN
		SELECT @ErrMsg =  N'You are not authorized on this function'
				,@ErrCode = 101
		RETURN 
	END
	
GO
GRANT VIEW DEFINITION ON [dbo].[RMS_userCheckPermission] TO [vnteam]
GO
GRANT EXECUTE ON [dbo].[RMS_UserCheckPermission] TO [bodbRMSNet]	 