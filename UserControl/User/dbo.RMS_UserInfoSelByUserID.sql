ALTER PROCEDURE [dbo].[RMS_UserInfoSelByUserID]
	@UserID		INT
AS
	/*
		Created: Johnson
		Date: 2012-05-10
		Task: Get user's info
		DB: DB054.bodb_RMS
		
		Revisions:
		
		Parameter's Explanation:
	*/ 
SET NOCOUNT ON
	SELECT c.custid, c.username, c.firstname, c.lastname, g.groupID, g.groupname, ui.enabled
	FROM rmUserInfo ui WITH(NOLOCK)
		INNER JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON ui.UserID = c.custid
		INNER JOIN rmGroup g WITH(NOLOCK) ON ui.groupID = g.groupID
	WHERE ui.UserID = @UserID

GO
GRANT VIEW DEFINITION ON [dbo].[RMS_UserInfoSelByUserID] TO [vnteam]
GO
GRANT EXECUTE ON [dbo].[RMS_UserInfoSelByUserID] TO [bodbRMSNet]