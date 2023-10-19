/*<info serverAlias="DBRMS-bodb_RMS" executers="bodbRMSNet" isFunction="0" isNested="0"></info>*/
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
		20231019@Jacob: Hot fix (#195750) - remove permission checking in stored procedure
		
		Parameter's Explanation:
	*/
BEGIN
	SET NOCOUNT ON
	DECLARE @startRun datetime  
			,@endRun datetime  
			,@duration int		
	
	SET @startRun=GETDATE()
		
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
