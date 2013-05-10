ALTER PROCEDURE [dbo].[RMS_UserInfoSel]
	@GroupID	INT = NULL,
	@Username	VARCHAR(50) = NULL
AS
	/*
		Created: Johnson
		Date: 2012-05-10
		Task: Get RMS's users
		DB: DB054.bodb_RMS
		
		Revisions:
		
		Parameter's Explanations:
	*/ 
SET NOCOUNT ON

	SELECT c.custid, c.username, c.firstname, c.lastname, g.groupid, g.groupname, ISNULL(creator.username,'') as creator, ui.CreatedDate, ui.enabled
	FROM rmUserInfo ui WITH(NOLOCK)
		INNER JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON ui.userid = c.custid
		INNER JOIN rmGroup g WITH(NOLOCK) ON ui.groupID = g.groupID
		LEFT JOIN bodb02.dbo.Customer creator WITH(NOLOCK) ON ui.creator = creator.custid
	WHERE ui.GroupID = ISNULL(@GroupID,ui.GroupID)
		AND c.username LIKE '%'+ ISNULL(@Username,c.username) + '%'
	ORDER BY ui.enabled DESC, g.groupName ASC, c.username ASC
GO
GRANT VIEW DEFINITION ON [dbo].[RMS_UserInfoSel] TO [vnteam]
GO
GRANT EXECUTE ON [dbo].[RMS_UserInfoSel] TO [bodbRMSNet]