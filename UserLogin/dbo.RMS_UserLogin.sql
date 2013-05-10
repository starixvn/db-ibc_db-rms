ALTER PROCEDURE [dbo].[RMS_UserLogin]
	@Username		VARCHAR(50),
	@Custid			INT = 0 OUTPUT,
	@userpwd		NVARCHAR(100),
	@LoginIP		VARCHAR(50),
	@LoginDomain	NVARCHAR(253) = NULL,
	@BrowserName	NVARCHAR(255) = NULL,
	@Platform		NVARCHAR(255) = NULL,  
	@CountryCode	VARCHAR(64) = NULL,
	@ErrCode INT = 0 OUTPUT,
	@ErrMsg			NVARCHAR(200) = '' OUTPUT,
	@Language		VARCHAR(2)= 'E'
AS
	/*
		Created: Johnson
		Date: 2012-05-03
		DB: DBTXN/BODB02
		Task: Admin login RMS
		
		Revisions:
			- 20130121@Johnson: change linked server DB054 to DBRMS
		Parameter's Explanation:
	*/ 
SET NOCOUNT ON 

	DECLARE @Begin		DATETIME
	DECLARE @End		DATETIME
	DECLARE @Duration	INT

	SET @Begin = GETDATE()

	DECLARE @LogData nvarchar(MAX),
		@db_userpwd nvarchar(50),
		@failedcount tinyint,		
		@enabled bit,
		@roleid int

	SELECT @LogData = '', @ErrMsg = '', @ErrCode = 0 

	SELECT @CustID = ISNULL(c.custid,0), @db_userpwd = c.userpwd, @RoleID = roleid, @failedcount = IsNull(logincount, 0),
			@UserName = username
	FROM dbo.customer c with (nolock)
	WHERE username = @UserName

	IF @@ROWCOUNT = 0 -- user not found
	BEGIN
		SELECT  @ErrMsg = case @Language 
							when 'E' then 'Wrong username or password.'
							when 'CS' then N'Wrong username or password.'
							when 'J' then N'IDまたはパスワードが正しくありません。'
							else N'Wrong username or password.'
						end,
		@ErrCode = 101,		
		@LogData = 'Admin:' + @UserName + ' Logged in to RMS SITE' + ' - ' + 'Result:Failed(User_Not_Found)'
	END
	ELSE IF @RoleID NOT IN (5,6,7,8,9,10)
	BEGIN
		SELECT  @ErrMsg = N'Wrong username or password.',
			@ErrCode = 102, 
			@LogData = 'Admin:' + @username + ' Logged in to RMS SITE' + ' - ' + 'Result:Failed(Not_Admin)'
	END
	ELSE IF @UserPWD <> @db_userpwd
	BEGIN
		SELECT @ErrMsg = N'Wrong username or password.',
			@ErrCode = 103,
			@LogData = 'Admin:' + @username + ' Logged in to RMS SITE' + ' - ' + 'Result:Failed(Password)' ,
			@failedcount = @failedcount + 1
		
		IF (@failedcount <= 255) -- max of tinyint
		BEGIN
			UPDATE customer with (rowlock, updlock) SET logincount = @failedcount WHERE custid = @custid
		END
	END
	
	IF (@ErrMsg = '') AND (@LogData = '')
	BEGIN
		--Check existing in RMS
		SELECT @enabled = enabled FROM DBRMS.bodb_RMS.dbo.rmUserInfo WITH(NOLOCK) WHERE UserID = @custid
		
		IF @@ROWCOUNT = 0 --User not admin RMS
		BEGIN
			SELECT @ErrMsg = case @Language 
								when 'E' then 'You have not permission to log in to RMS.'
								when 'CS' then N'You have not permission to log in to RMS.'
								when 'J' then N'You have not permission to log in to RMS.'
								else N'You have not permission to log in to RMS.'
							end,
			@ErrCode = 104,		
			@LogData = 'Admin:' + @UserName + ' Logged in to RMS SITE' + ' - ' + 'Result:Failed(User_Not_Permission)'	
		END
		
		IF @enabled = 0 
		BEGIN
			SELECT @ErrMsg = case @Language 
								when 'E' then 'Your A/C was disabled, Please contact your supervisor..'
								when 'CS' then N'Your A/C was disabled, Please contact your supervisor.'
								when 'J' then N'Your A/C was disabled, Please contact your supervisor.'
								else N'Your A/C was disabled, Please contact your supervisor.'
							end,
			@ErrCode = 105,		
			@LogData = 'Admin:' + @UserName + ' Logged in to RMS SITE' + ' - ' + 'Result:Failed(A/C_Disabled)'			
		END
		ELSE
		BEGIN
			UPDATE customer with (rowlock, updlock)
			SET logincount = 0, iplogin = @LoginIP, lastlogged = CURRENT_TIMESTAMP, on_sessionid = 0
			WHERE custid = @custid

			SET @LogData = 'Admin:' + @username + ' Logged in to RMS SITE' + ' - ' + 'Result:Success'		
		END
	END
	
	IF @LogData <> ''
	BEGIN		
		SET @End = GETDATE()
		SET @Duration = DATEDIFF(millisecond,@Begin,@End)
		
		BEGIN TRY
			EXEC DBLOG.bodb_customerlog.dbo.RMS_WriteLog_UserLog_Login 
				 @UserID = @CustID, 
				 @LoginIP = @LoginIP,	
				 @ActionID = 10200,
				 @Doing = @LogData,
				 @DomainName = @LoginDomain,
				 @BrowserName = @BrowserName,
				 @Platform = @Platform,
				 @CountryCode = @CountryCode,
				 @Duration = @Duration
		END TRY
		BEGIN CATCH
			SELECT @LogData = @LogData + '- ErrMsg:' + ERROR_MESSAGE()
			
			EXEC bodb_customerlog.dbo.RMS_WriteLog_UserLog_Login 
				 @UserID = @CustID, 
				 @LoginIP = @LoginIP,	
				 @ActionID = 10200,
				 @Doing = @LogData,
				 @DomainName = @LoginDomain,
				 @BrowserName = @BrowserName,
				 @Platform = @Platform,
				 @CountryCode = @CountryCode,
				 @Duration = @Duration
		END CATCH
	END
	
GO
GRANT VIEW DEFINITION ON [dbo].[RMS_UserLogin] TO [vnteam]
GO
GRANT EXECUTE ON [dbo].[RMS_UserLogin] TO [bodbRMSNet]
