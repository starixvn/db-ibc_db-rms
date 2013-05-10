ALTER PROCEDURE [dbo].[RMS_UserInfoUpdUserPwd]
	@AdminID	INT,
	@CustID		INT,
	@userpwd	NVARCHAR(50),
	@IP			VARCHAR(50),
	@ErrCode	INT = 0 OUTPUT,
	@ErrMsg		VARCHAR(500) = '' OUTPUT
AS
	/*
		Created: Johnson
		Date: 2012-05-11
		Task: Update user's password
		DB: DBTXN/bodb02
		
		Revisions:
			- 20120523@Elodie: Write log
			- 20130121@Johnson: change linked server DB054 to DBRMS
			- 20130313@Johnson: Fix format log by xml format
		Parameter's Explanation:
	*/ 
SET NOCOUNT ON

	DECLARE @startRun datetime  
			,@endRun datetime  
			,@duration int		
		
	SET @startRun=GETDATE()
	
	IF @AdminID <> @CustID
	BEGIN
		EXEC DBRMS.bodb_RMS.dbo.RMS_UserCheckPermission @UserID = @AdminID ,@FuncKey = 'ManageUser', @ErrCode = @ErrCode OUTPUT, @ErrMsg = @ErrMsg OUTPUT
		
		IF @ErrCode > 0
			RETURN
	END
		
	DECLARE @db_userpwd NVARCHAR(50)
	
	SELECT @db_userpwd = userpwd FROM Customer WITH(NOLOCK) WHERE custid = @custid
	
	IF @@ROWCOUNT = 0 OR @db_userpwd = @userpwd
		RETURN
	
	UPDATE Customer WITH(UPDLOCK,ROWLOCK) 
	SET userpwd = @userpwd
	WHERE custid = @custid
	
	DECLARE @LogData NVARCHAR(4000), @LogErr NVARCHAR(MAX)
	
	
	SELECT @LogData = '<RMS_UserInfoUpdUserpwd CustID="' + COALESCE(CONVERT(VARCHAR(10),@CustID),SPACE(1)) + '" ' +												
						'IP="' + COALESCE(@IP,SPACE(1)) + '" />'
		
	SET @endRun = GETDATE()  
	SET @duration  = DATEDIFF (MILLISECOND,@startRun,@endRun)  
	
	BEGIN TRY
		--Write log in IBC
		EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP  
			@UserID			= @AdminID, 
			@CustID			= @CustID,				
			@ActionID		= 10301, 
			@TrackingValue	= @LogData, 
			@duration		= @duration
	END TRY
	BEGIN CATCH		
		SELECT @LogErr = '<RMS_UserInfoUpdUserpwd CustID="' + COALESCE(CONVERT(VARCHAR(10),@CustID),SPACE(1)) + '" ' +												
						'IP="' + COALESCE(@IP,SPACE(1)) + '" ' + 
						'ErrMsg='+ COALESCE(ERROR_MESSAGE(),SPACE(1)) + '" />'
				
		EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP  
			@UserID			= @AdminID, 
			@CustID			= @CustID,				
			@ActionID		= 10301, 
			@TrackingValue	= @LogErr, 
			@duration		= @duration
	END CATCH	
	
	BEGIN TRY
		--Write log in RMS
		EXEC DBLOG.bodb_CustomerLog.dbo.RMS_WriteLog_UserLog_RunSP  
			@UserID			= @AdminID, 
			@CustID			= @CustID,				
			@ActionID		= 10301, 
			@TrackingValue	= @LogData, 
			@duration		= @duration
	END TRY
	BEGIN CATCH
		SELECT @LogErr = '<RMS_UserInfoUpdUserpwd> CustID="' + COALESCE(CONVERT(VARCHAR(10),@CustID),SPACE(1)) + '" ' +												
						'IP="' + COALESCE(@IP,SPACE(1)) + '" ' + 
						'ErrMsg='+ COALESCE(ERROR_MESSAGE(),SPACE(1)) + '" ' + 
					'</RMS_UserInfoUpdUserpwd>'
					
		--Write log in RMS
		EXEC bodb_CustomerLog.dbo.RMS_WriteLog_UserLog_RunSP  
			@UserID			= @AdminID, 
			@CustID			= @CustID,				
			@ActionID		= 10301, 
			@TrackingValue	= @LogErr, 
			@duration		= @duration
	END CATCH
GO
GRANT VIEW DEFINITION ON [dbo].[RMS_UserInfoUpdUserPwd] TO  [vnteam]
GO
GRANT EXECUTE ON [dbo].[RMS_UserInfoUpdUserPwd] TO [bodbRMSNet]