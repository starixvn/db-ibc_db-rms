ALTER PROCEDURE [dbo].[RMS_GroupInfoSelByGroupID]
	@GroupID	INT
AS
	/*
		Created: Johnson
		Date: 2012-05-10
		Task: get group info by id
		DB: DB054.bodb_RMS
		
		Revisions:
		
		Parameter's Explanation:
	*/ 
SET NOCOUNT ON

	SELECT GroupName, Description
	FROM rmGroup WITH(NOLOCK)
	WHERE groupID = @GroupID

GO
GRANT VIEW DEFINITION ON [dbo].[RMS_GroupInfoSelByGroupID] TO [vnteam]
GO
GRANT EXECUTE ON [dbo].[RMS_GroupInfoSelByGroupID] TO [bodbRMSNet]