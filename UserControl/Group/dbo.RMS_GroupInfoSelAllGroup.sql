ALTER PROCEDURE [dbo].[RMS_GroupInfoSelAllGroup]
AS
	/*
		Created: Johnson
		Date: 2012-05-10
		Task: Select all group available
		DB: DB054.bodb_RMS
		
		Revisons:
		
		Parameter's Explanation:
	*/ 
SET NOCOUNT ON

	SELECT GroupID,GroupName
	FROM rmGroup WITH(NOLOCK)
	ORDER BY groupName

GO
GRANT VIEW DEFINITION ON [dbo].[RMS_GroupInfoSelAllGroup] TO [vnteam]
GO
GRANT EXECUTE ON [dbo].[RMS_GroupInfoSelAllGroup] TO [bodbRMSNet]