ALTER PROCEDURE [dbo].[RMS_CustomerIns]
	@adminid	INT,
	@username	VARCHAR(30),
	@level		INT,
	@IP			VARCHAR(50),	
	@ErrCode	INT = 0 OUTPUT,
	@ErrMsg		VARCHAR(500) = '' OUTPUT
AS
	/*
		Created: Johnson
		Date: 20121024
		Task: Insert customer for monitoring
		DB: DBRMS/bodb_RMS
		
		Revisions:
			- 20130313@Johnson: Fix format log by xml format
		Parameter's Explanation:
	*/
SET NOCOUNT ON

	DECLARE @startRun datetime  
			,@endRun datetime  
			,@duration int		
	
	SET @startRun=GETDATE()
	
	EXEC RMS_UserCheckPermission @UserID = @AdminID ,@FuncKey = 'ManageCustomer', @ErrCode = @ErrCode OUTPUT, @ErrMsg = @ErrMsg OUTPUT
	
	IF @ErrCode > 0
		RETURN
	
	DECLARE @custid INT, @roleid TINYINT
	
	SELECT @custid = custid , @roleid = roleid
	FROM bodb02.dbo.custinfo WITH(NOLOCK)
	WHERE username = @username
	
	IF ISNULL(@custid ,0) = 0 
	BEGIN
		SELECT @ErrMsg = 'Invalid customer.',
				@ErrCode = 100
		RETURN
	END
	
	IF ISNULL(@roleid ,0) <> 1
	BEGIN
		SELECT @ErrMsg = 'This is not a member.',
				@ErrCode = 101
		RETURN
	END
	
	IF EXISTS (SELECT 1 FROM rmCustomer WITH(NOLOCK) WHERE custid = @custid)
	BEGIN
		SELECT @ErrMsg = 'This customer is exists.',
				@ErrCode = 102
		RETURN
	END
	
	INSERT INTO rmCustomer (custid, username, [level], createdDate, creator)
	VALUES (@custid, @username, @level, CURRENT_TIMESTAMP, @AdminID)
	
	DECLARE @LogData NVARCHAR(500)	
	
	SELECT @LogData = '<RMS_CustomerIns UserName="' + COALESCE(@Username,SPACE(1)) + '" ' +						
						'level="' + COALESCE(CONVERT(VARCHAR(10),@level),SPACE(1)) + '" ' +
						'IP="' + COALESCE(@IP,SPACE(1)) + '" />'

	SET @endRun = GETDATE()  
	SET @duration  = DATEDIFF (MILLISECOND,@startRun,@endRun)   
	
	EXEC DBLOG.bodb_CustomerLog.[dbo].[RMS_WriteLog_UserLog_RunSP] 
		@userid		= @AdminID, 
		@actionid	= 10400,	
		@TrackingValue = @LogData, 					
		@duration	= @duration
	
GO 
GRANT EXECUTE ON [dbo].[RMS_CustomerIns] TO [bodbRMSNet]