 ALTER PROCEDURE [dbo].[RMS_GroupInfoSelUserGroup]
	@GroupID	INT
AS
	/*
		Created: Johnson
		Date: 2012-05-09
		Task: Get users of group
		DB: DB054.bodb_RMS
		
		Revisions:
		
		Parameter's Explanation:
	*/
SET NOCOUNT ON

	SELECT c.username, c.firstname, c.lastname, c.creatdate, ui.enabled, creator.username as creator
	FROM rmUserInfo ui WITH(NOLOCK)
		INNER JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON ui.userid = c.CustID
		LEFT JOIN bodb02.dbo.Customer creator WITH(NOLOCK) ON c.creator = creator.Custid	
	WHERE GroupID = @GroupID

GO
GRANT VIEW DEFINITION ON [dbo].[RMS_GroupInfoSelUserGroup] TO [vnteam]
GO
GRANT EXECUTE ON [dbo].[RMS_GroupInfoSelUserGroup] TO [bodbRMSNet]