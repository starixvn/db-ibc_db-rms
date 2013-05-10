 ALTER PROCEDURE [dbo].[RMS_UserRecheckIn]
	@On_UserID		INT,
	@isKickedOut	BIT = 0 OUTPUT
AS
	/*
		Created: Johnson
		Date: 2012-05-07
		Task: Admin re-checkin RMS
		DB: DB054.bodb_RMS
		
		Revisions:
		
		Paramter's Explanation:
	*/
SET NOCOUNT ON

	IF EXISTS (SELECT 1 FROM rmOn_User WITH(NOLOCK) WHERE on_userid = @on_userid AND isKickedOut = 1)
		SELECT @isKickedOut = 1
	ELSE
	BEGIN
		SELECT @isKickedOut = 0
		
		UPDATE rmOn_User WITH(UPDLOCK,ROWLOCK)
		SET reload_time = getdate()
		WHERE on_userid = @on_userid
		
		IF @@ROWCOUNT = 0
			SELECT @isKickedOut = 1
	END

GO 
GRANT VIEW DEFINITION ON [dbo].[RMS_UserReCheckIn] TO [vnteam]
GO
GRANT EXECUTE ON [dbo].[RMS_UserReCheckIn] TO [bodbRMSNet]