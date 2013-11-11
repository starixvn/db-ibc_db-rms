ALTER PROCEDURE [dbo].[RMS_DangerousAgentIns]
	@username NVARCHAR(50)= '',	
	@userid INT = 0,
	@IP VARCHAR(50)='',
	@ErrCode INT = 0 OUTPUT,
	@ErrMsg  NVARCHAR(500) = '' OUTPUT
AS
	/*
		Created: Johnson
		Date: 2013-11-11
		Task: Add new dangerous agent into RMS
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
		
	DECLARE @custid INT, @roleid INT
	
	SELECT @custid = custid, @roleid = roleid
	FROM DBACC.bodb02.dbo.customer WITH(NOLOCK)
	WHERE username = @username
	
	IF @custid IS NULL OR @roleid <> 2
	BEGIN
		SELECT @ErrMsg = 'Invalid Agent.',
				@ErrCode = 100
		RETURN
	END
	
	IF EXISTS(SELECT 1 FROM rmAgent WITH(NOLOCK) WHERE AgentID = @custid)
	BEGIN
		SELECT @ErrMsg = 'This agent existed.',
				@ErrCode = 101
		RETURN
	END
	
	INSERT INTO rmAgent (AgentID,username,creator,createdDate)
	VALUES (@custid,@username,@userid,GETDATE())
	
	IF @@ERROR >0
	BEGIN
		SELECT @ErrMsg = 'Add dangerous agent fail',
				@ErrCode = 101
		RETURN
	END
	
	DECLARE @LogData NVARCHAR(500)	
	
	SELECT @LogData = '<RMS_DangerousAgentIns UserName="' + COALESCE(@Username,SPACE(1)) + '" ' +												
						'AgentID="' + COALESCE(CONVERT(VARCHAR(10),@custID),SPACE(1)) + '" ' +												
						'IP="' + COALESCE(@IP,SPACE(1)) + '" />'

	SET @endRun = GETDATE()  
	SET @duration  = DATEDIFF (MILLISECOND,@startRun,@endRun)   
	
	EXEC DBLOG.bodb_CustomerLog.[dbo].[RMS_WriteLog_UserLog_RunSP] 
		@userid		= @UserID, 
		@actionid	= 10402,	
		@TrackingValue = @LogData, 					
		@duration	= @duration
	
END 
GO
GRANT EXECUTE ON [dbo].[RMS_DangerousAgentIns] TO [bodbRMSNet]