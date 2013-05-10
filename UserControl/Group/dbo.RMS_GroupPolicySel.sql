ALTER PROCEDURE [dbo].[RMS_GroupPolicySel]
	@groupid	INT
AS
	/*
		Created: Johnson
		Date: 2012-05-08
		Task: Get group policy
		DB: DB054.bodb_RMS
		
		Revisions:
		
		Parameter's Explanation:
	*/ 
SET NOCOUNT ON

	SELECT f.FuncID, f.FuncName, f.DisplayOrder, f.ParentID, f.ParentName, ISNULL(gp.Policy,0) as Policy
	FROM rmFunction f WITH(NOLOCK)
		LEFT JOIN rmGroupPolicy gp WITH(NOLOCK) ON gp.GroupID = @groupid AND gp.funcid = f.funcid	
	ORDER BY f.ParentID ,f.DisplayOrder ASC

GO
GRANT VIEW DEFINITION ON [dbo].[RMS_GroupPolicySel] TO [vnteam]
GO
GRANT EXECUTE ON [dbo].[RMS_GroupPolicySel] TO [bodbRMSNet]