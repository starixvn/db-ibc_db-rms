 ALTER PROCEDURE [dbo].[RMS_UserCheckIn]
	@custid			INT,
	@NetSessionID	VARCHAR(50),
	@on_userid		INT OUTPUT,
	@IP				NVARCHAR(50)
AS
	/*
		Created: Johnson
		Date: 2012-05-07
		Task: admin check in RMS
		DB: DB054.bodb_RMS
		
		Revisions:
		
		Parameter's Explanation:
	*/
SET NOCOUNT ON 

	UPDATE rmOn_User WITH(UPDLOCK,ROWLOCK) SET iskickedout = 1 WHERE custid = @custid
	
	INSERT INTO rmOn_User (custid, NetSessionID, isKickedOut, IP) 
	VALUES (@custid, @NetSessionID, 0, @IP)
	
	SELECT @on_userid = SCOPE_IDENTITY()
	
GO
GRANT VIEW DEFINITION ON [dbo].[RMS_UserCheckIn] TO [vnteam]
GO
GRANT EXECUTE ON [dbo].[RMS_UserCheckIn] TO [bodbRMSNet]