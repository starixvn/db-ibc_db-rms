/*<info serverAlias="DBRMS-bodb_RMS" executers="bodbRMSNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[RMS_CustomerUpd]
	@AdminID	INT,
	@custid		INT,
	@level		INT,	
	@IP			VARCHAR(50),
	@ErrCode	INT = 0 OUTPUT,
	@ErrMsg		VARCHAR(500) = '' OUTPUT
 AS
	/*
		Created: Johnson
		Date: 20121024
		Task: Update customer info
		DB: DBRMS/bodb_RMS
		
		Revisions:
			- 20130313@Johnson: Fix format log by xml format
			- 20231019@Jacob: Hot fix (#195750) - remove permission checking in stored procedure
		Parameter's Explanation:
	*/
SET NOCOUNT ON
	DECLARE @startRun datetime  
			,@endRun datetime  
			,@duration int		
	
	SET @startRun=GETDATE()
	
	
	
	DECLARE @old_level INT
	
	SELECT @old_level = level
	FROM rmCustomer WITH(NOLOCK)
	WHERE custid = @custid
	
	IF @@ROWCOUNT = 0 OR @old_level = @level
		RETURN
	
	UPDATE rmCustomer WITH(UPDLOCK,ROWLOCK)
	SET level = @level
	WHERE custid = @custid
	
	DECLARE @LogData VARCHAR(4000), @LogData_Old VARCHAR(4000)
		
	SELECT @LogData = '<RMS_CustomerUpd custid="'+ COALESCE(CAST(@custid AS VARCHAR(10)), SPACE(1)) + '" ' +
										'level="' + COALESCE(CAST(@level AS VARCHAR(10)) , SPACE(1)) + '" />'
	
	SELECT @LogData_Old = '<RMS_CustomerUpd custid="'+ COALESCE(CAST(@custid AS VARCHAR(10)), SPACE(1)) + '" ' +
										'level="' + COALESCE(CAST(@old_level AS VARCHAR(10)) , SPACE(1)) + '" />' 
	
	SET @endRun = GETDATE()  
	SET @duration  = DATEDIFF (MILLISECOND,@startRun,@endRun) 
	
	EXEC DBLOG.bodb_CustomerLog.[dbo].[RMS_WriteLog_UserLog_RunSP] 
		@Userid		= @Adminid,	
		@ActionID	= 10401,
		@TrackingValue	= @LogData,
		@TrackingValue2 = @LogData_Old,
		@Duration	= @duration

GO
