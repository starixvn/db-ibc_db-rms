ALTER PROCEDURE [dbo].[RMS_GroupPolicyUpd]
	@adminID		INT,
	@GroupID		INT,
	@GroupPolicy	VARCHAR(4000) = '',
	@IP				VARCHAR(50),
	@ErrCode		INT = 0 OUTPUT,
	@ErrMsg			VARCHAR(500) = '' OUTPUT
AS
	/*
		Created: Johnson
		Date: 2012-05-08
		Task: grant permission to group
		DB: DBRMS/bodb_RMS
		
		Revisions:
			- 20120523@Elodie: Write log
			- 20130313@Johnson: Fix format log by xml format
		Parameter's Explanation:
			- @Policy: contains ID's function changed and new policy 
					ex: '7,1;8,2;4,0'
	*/
SET NOCOUNT ON  

	DECLARE @startRun datetime  
		,@endRun datetime  
		,@duration int		
	
	SET @startRun=GETDATE()
	
	EXEC dbo.RMS_UserCheckPermission @UserID = @AdminID ,@FuncKey = 'ManageGroup', @ErrCode = @ErrCode OUTPUT, @ErrMsg = @ErrMsg OUTPUT
	
	IF @ErrCode > 0
		RETURN
	
	DECLARE @Func TABLE (FuncID INT, Policy INT)
	
	INSERT INTO @Func (funcid, policy)
		SELECT funcid,policy
		FROM f_RMS_PolicySplit (@GroupPolicy,';',',')
		
	UPDATE gp
	SET gp.Policy = t.Policy
	FROM rmGroupPolicy gp 
		INNER JOIN @Func t ON gp.groupid = @groupid AND gp.funcid = t.funcid
	
	INSERT INTO rmGroupPolicy (GroupID, FuncID, Policy)
		SELECT @GroupID, t.FuncID, t.Policy 
		FROM @Func t
			LEFT OUTER JOIN rmGroupPolicy gp WITH(NOLOCK) ON gp.groupID = @GroupID AND gp.funcID = t.FuncID
		WHERE gp.FuncID IS NULL		
	
	/**************Write to Log table for each action********************/
	
	DECLARE @LogData NVARCHAR(500)
	SELECT @LogData = '<RMS_GroupPolicyUpd GroupPolicy="' + COALESCE(@GroupPolicy,SPACE(1)) + '" ' +
						'IP="' + COALESCE(@IP,SPACE(1)) + '" />'

	SET @endRun = getdate()  
	SET @duration  = datediff (millisecond,@startRun,@endRun)   

	EXEC DBLOG.bodb_CustomerLog.[dbo].[RMS_WriteLog_UserLog_UserControl] 
		@custID = @GroupID, 
		@Doing = @LogData, 
		@userid = @AdminID, 
		@TypeID = 0, 
		@actionid = 10002, 
		@duration = @Duration
	
GO
GRANT VIEW DEFINITION ON [dbo].[RMS_GroupPolicyUpd] TO [vnteam]
GO
GRANT EXECUTE ON [dbo].[RMS_GroupPolicyUpd] TO [bodbRMSNet]