ALTER PROCEDURE [dbo].[RMS_UserPolicySel]
	@UserID		INT
AS
	/*
		Created: Johnson
		Date: 2012-05-14
		Task: Get policy of user
		DB: DB054.bodb_RMS
		
		Revisions:
		
		Parameter's Explanation:
	*/ 
SET NOCOUNT ON

	SELECT f.funcid, f.funcname, f.DisplayOrder, f.ParentID, f.ParentName, ISNULL(u.policy,0) UserPolicy, ISNULL(g.policy,0) GroupPolicy
	FROM rmFunction f WITH(NOLOCK)
	LEFT JOIN 	
		(
			SELECT FuncID, Policy 
			FROM rmUserPolicy WITH(NOLOCK) 
			WHERE UserID = @UserID
		) u ON f.funcid  = u.funcid
	LEFT JOIN
		(
			SELECT FuncID, Policy
			FROM rmGroupPolicy gp WITH(NOLOCK)
				INNER JOIN rmUserInfo ui WITH(NOLOCK) ON ui.userid = @userid AND ui.groupid = gp.groupid		
		) g ON f.funcid = g.funcid
	ORDER BY f.ParentID ,f.DisplayOrder ASC

GO
GRANT VIEW DEFINITION ON [dbo].[RMS_UserPolicySel] TO [vnteam]
GO
GRANT EXECUTE ON [dbo].[RMS_UserPolicySel] TO [bodbRMSNet]