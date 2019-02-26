/*<info serverAlias="DBCUST-CUSTDB" executers="bodbRMSNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[RMS_UserInfoAddNew]
	@AdminID	INT = 0,	
	@Username	VARCHAR(50),
	@custid		INT = 0 OUTPUT,
	@userpwd	VARCHAR(50),
	@firstname	NVARCHAR(50) = '',
	@lastname	NVARCHAR(50) = '',
	@groupid	INT,
	@IP			VARCHAR(50),
	@ErrCode	INT = 0 OUTPUT,
	@ErrMsg		VARCHAR(500) = '' OUTPUT
AS
	/*
		Created: Johnson
		Date: 2012-05-14
		Task: Insert user's info 
		DB: DBTXN/bodb02
		
		Revisions:
			- 20120523@Elodie: Write log
			- 20120619@Johnson: Manually rollback
			- 20130121@Johnson: change linked server DB054 to DBRMS and try catch for writing log
			- 20130313@Johnson: Fix format log by xml format
			- 20181011@Dominic: Check existing username/username2 in archive DB  [Redmine:103011]
		Parameter's Explanation:
	*/
SET NOCOUNT ON

	DECLARE @startRun datetime  
		,@endRun datetime  
		,@duration int		
	
	SET @startRun=GETDATE()
	
	EXEC DBRMS.bodb_RMS.dbo.RMS_UserCheckPermission @UserID = @AdminID ,@FuncKey = 'ManageUser', @ErrCode = @ErrCode OUTPUT, @ErrMsg = @ErrMsg OUTPUT
	
	IF @ErrCode > 0
		RETURN
	
	IF EXISTS (SELECT 1 FROM Customer WITH(NOLOCK) WHERE username = @username)
	OR EXISTS(SELECT 1 FROM Dep_Customer_Archived WITH (NOLOCK) WHERE username= @username)
	BEGIN
		SELECT @ErrMsg = 'This username is not available',
			@ErrCode = 100
		RETURN
	END
	
	DECLARE @roleid		INT,
			@pwdexpiry	DATETIME,
			@closed		BIT
	
	SELECT @pwdexpiry = DATEADD (month,1,CURRENT_TIMESTAMP),
			@roleid   = 6,
			@closed	  = 0
	
	
	INSERT  INTO customer (username, userpwd, roleid, firstname, lastname, creator, pwdexpiry, creatdate)
	VALUES               (@username, @userpwd, @roleid, @firstname, @lastname, @AdminID, @pwdexpiry, current_timestamp);
	
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrMsg ='Add user failed.',
			   @ErrCode = 101;
		RETURN;
	END
	
	SELECT @CustID = SCOPE_IDENTITY();
	
	INSERT  INTO dbo.custinfo (username, [custid], [currency], [MaxPerMatch], [MaxPerMatch2], [MaxPerMatch3], [MaxPerMatch5], [MaxPerMatch8], [MaxPerMatch10], [MaxPerMatch11], [MaxPerMatch12], [MaxPerMatch99], [Maxpermatch151], [maxpermatch201], [MaxPerMatch161], [MaxPerMatch99MP], [MaxPerBall161], [MaxPerMatch151_OT], [roleid], [mrecommend], [recommend], [dangercust], [autosuspend], [reject], [credit], [MatchLimit], [VirtualMultiplier], [DisableHorseRacing], [DisableFinancial], [DisableCasino], [DisableOutright], [DisableOpenTote], [DisableBingo], [DisableNumber], [SyncCasino], [danger], [danger2], [danger3], [Enabled], [closed])
	VALUES                   (@username, @custid, NULL, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, @roleid, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, @closed);
	
	IF @@ERROR <> 0
	BEGIN
		--roll back transaction
		DELETE FROM customer WITH(ROWLOCK) WHERE custid = @custid
		
		SELECT @ErrMsg = 'Add user failed.',
			   @ErrCode = 102;
		RETURN;
	END

	
	INSERT INTO DBRMS.bodb_RMS.dbo.rmUserInfo (UserID, GroupID, enabled, creator, CreatedDate)
	VALUES (@CustID, @GroupID, 1, @AdminID, current_timestamp)
	
	IF @@ERROR <> 0
	BEGIN
		--roll back transaction
		DELETE FROM customer WITH(ROWLOCK) WHERE custid = @custid
		DELETE FROM custinfo WITH(ROWLOCK) WHERE custid = @custid
		
		SELECT @ErrMsg = 'Add user failed.',
			   @ErrCode = 103;
		RETURN;
	END
	
	--initial policy
	INSERT INTO DBRMS.bodb_RMS.dbo.rmUserPolicy (funcid,userid,policy)
	SELECT funcid, @custid, 0
	FROM DBRMS.bodb_RMS.dbo.rmFunction WITH(NOLOCK)
	
	IF @@ERROR <> 0
	BEGIN
		--roll back transaction
		DELETE FROM customer WITH(ROWLOCK) WHERE custid = @custid
		DELETE FROM custinfo WITH(ROWLOCK) WHERE custid = @custid
		DELETE FROM DBRMS.bodb_RMS.dbo.rmUserInfo WITH (ROWLOCK) WHERE userid = @custid
		
		SELECT @ErrMsg = 'Add user failed.',
			   @ErrCode = 104;
		RETURN;
		
	END
	/**************Write to Log table********************/
	DECLARE @LogData NVARCHAR(MAX)	
	SELECT @LogData = '<RMS_UserInfoAddNew UserName="' + COALESCE(@Username,SPACE(1)) + '" ' +
						'FirstName="' + COALESCE(@firstname,SPACE(1)) + '" ' +
						'LastName="' + COALESCE(@lastname,SPACE(1)) + '" ' +
						'GroupID="' + COALESCE(CONVERT(VARCHAR(10),@groupID),SPACE(1)) + '" ' +
						'IP="' + COALESCE(@IP,SPACE(1)) + '" />'

	SET @endRun = GETDATE()  
	SET @duration  = DATEDIFF (MILLISECOND,@startRun,@endRun)   
	
	BEGIN TRY
		EXEC DBLOG.bodb_CustomerLog.[dbo].[RMS_WriteLog_UserLog_UserControl] 
			@custID = @custid, 
			@Doing = @LogData, 
			@userid = @AdminID, 
			@TypeID = 1, 
			@actionid = 10003, 
			@duration = @duration
	END TRY
	BEGIN CATCH 		
		SELECT @LogData = '<RMS_UserInfoAddNew UserName="' + COALESCE(@Username,SPACE(1)) + '" ' +
						'FirstName="' + COALESCE(@firstname,SPACE(1)) + '" ' +
						'LastName="' + COALESCE(@lastname,SPACE(1)) + '" ' +
						'GroupID="' + COALESCE(CONVERT(VARCHAR(10),@groupID),SPACE(1)) + '" ' +
						'IP="' + COALESCE(@IP,SPACE(1)) + '" ' + 
						'ErrMsg="' + COALESCE(ERROR_MESSAGE(),SPACE(1)) + '" />'
		
		EXEC bodb_CustomerLog.[dbo].[RMS_WriteLog_UserLog_UserControl] 
			@custID = @custid, 
			@Doing = @LogData, 
			@userid = @AdminID, 
			@TypeID = 1, 
			@actionid = 10003, 
			@duration = @duration
	END CATCH
GO
GRANT VIEW DEFINITION ON [dbo].[RMS_UserInfoAddNew] TO [vnteam]
GO
GRANT EXECUTE ON [dbo].[RMS_UserInfoAddNew] TO [bodbRMSNet]
	