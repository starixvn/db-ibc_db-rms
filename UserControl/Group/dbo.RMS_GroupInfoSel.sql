 ALTER PROCEDURE [dbo].[RMS_GroupInfoSel]	
AS
	/*
		Created: Johnson
		Date: 2012-05-08
		Task: Get RMS's groups 
		DB: DB054.bodb_RMS
		
		Revisions:
		
		Parameter's Explanation:
			
	*/	
SET NOCOUNT ON

	SELECT g.GroupID, g.GroupName, ISNULL(p.Users,0) as NoUsers, ISNULL(g.Description,'') as Description, ISNULL(c.username,'') as Creator, g.createdDate
	FROM rmGroup g WITH(NOLOCK) 
		LEFT JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON g.creator = c.custid
		LEFT JOIN 
		(
			SELECT GroupID, count(1) users
			FROM rmUserInfo WITH(NOLOCK)
			GROUP BY GroupID
		) p ON g.groupID = p.groupID
	ORDER BY  groupName
GO
GRANT VIEW DEFINITION ON [dbo].[RMS_GroupInfoSel] TO [vnteam]
GO
GRANT EXECUTE ON [dbo].[RMS_GroupInfoSel] TO [bodbRMSNet]

	