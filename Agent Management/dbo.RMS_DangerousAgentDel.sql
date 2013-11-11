ALTER PROCEDURE [dbo].[RMS_DangerousAgentDel]
	@agentid INT,
	@username NVARCHAR(50),
	@userid INT,
	@IP NVARCHAR(50)= '',
	@ErrCode INT = 0 OUTPUT,
	@ErrMsg NVARCHAR(500) = '' OUTPUT
AS
	/*
		Created: Johnson
		Date: 2013-11-11
		Task: Remove agent from dangerous list
		DB: DBRMS/bodb_RMS
		
		Revisions:
		
		Parameter's Explanation:
	*/
BEGIN
	SET NOCOUNT ON
	DECLARE @startRun datetime  
			,@endRun datetime  
			,@duration int		
	
	SET @startRun=GETDATE()
	
	EXEC RMS_UserCheckPermission @UserID = @UserID ,@FuncKey = 'ManageAgent', @ErrCode = @ErrCode OUTPUT, @ErrMsg = @ErrMsg OUTPUT
	
	IF @ErrCode > 0
		RETURN
		
	DELETE rmAgent WITH(ROWLOCK,UPDLOCK)
	WHERE agentid = @agentid
	
	IF @@ERROR > 0
	BEGIN
		SELECT @ErrMsg = 'Delete agent fail',
				@ErrCode = 101
		RETURN
	END		
	
	DECLARE @LogData NVARCHAR(500)	
	
	SELECT @LogData = '<RMS_DangerousAgentDel UserName="' + COALESCE(@Username,SPACE(1)) + '" ' +												
						'AgentID="' + COALESCE(CONVERT(VARCHAR(10),@AgentID),SPACE(1)) + '" ' +												
						'IP="' + COALESCE(@IP,SPACE(1)) + '" />'

	SET @endRun = GETDATE()  
	SET @duration  = DATEDIFF (MILLISECOND,@startRun,@endRun)   
	
	EXEC DBLOG.bodb_CustomerLog.[dbo].[RMS_WriteLog_UserLog_RunSP] 
		@userid		= @UserID, 
		@actionid	= 10403,	
		@TrackingValue = @LogData, 					
		@duration	= @duration
END
GO
GRANT EXECUTE ON  [dbo].[RMS_DangerousAgentDel] TO [bodbRMSNet]