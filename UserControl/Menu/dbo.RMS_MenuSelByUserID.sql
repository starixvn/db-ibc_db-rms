 ALTER PROCEDURE [dbo].[RMS_MenuSelByUserID]
	@userid		INT
AS 
	/*
		Created: Johnson
		Date: 2012-05-07
		Task: Get menu by userid
		DB: DB054.bodb_RMS
		
		Revisions:
		
		Parameter's Explanation:
	*/
SET NOCOUNT ON
	DECLARE @tmpFunction TABLE (funcid int, policy int)
	
	INSERT INTO @tmpFunction (funcid, policy)
	SELECT CASE WHEN ISNULL(u.funcid ,0) = 0 THEN g.funcid ELSE u.funcid END as FuncID,
			CASE WHEN ISNULL(u.policy,0) < ISNULL(g.policy,0) THEN ISNULL(g.policy,0) ELSE ISNULL(u.policy,0) END as Policy
	FROM
	(
		SELECT FuncID,Policy 
		FROM rmUserPolicy WITH(NOLOCK) 
		WHERE userid = @userid
	) u
	FULL OUTER JOIN
	(
		SELECT FuncID,Policy 
		FROM rmUserInfo ui WITH(NOLOCK)
		INNER JOIN rmGroupPolicy gp WITH(NOLOCK) ON ui.groupid = gp.groupid
		WHERE ui.userid = @userid
	) g ON u.funcid = g.funcid
	
	SELECT
		m.ParentID,
		m.ParentName,
		m.MenuID,
		m.MenuName,
		m.URL,
		m.DisplayOrder
	FROM rmMenu m WITH(NOLOCK) 	
		INNER JOIN @tmpFunction p ON p.funcid = m.funcid
	WHERE m.enabled = 1 AND p.policy > 0
	ORDER BY m.parentID, m.displayOrder
	
	SELECT f.funcid, f.funcName, f.funckey, t.policy
	FROM @tmpFunction t
		INNER JOIN rmFunction f WITH(NOLOCK) ON t.funcid = f.funcid
	WHERE t.policy > 0
	
GO
GRANT VIEW DEFINITION ON [dbo].[RMS_MenuSelByUserID] TO [vnteam]
GO
GRANT EXECUTE ON [dbo].[RMS_MenuSelByUserID] TO [bodbRMSNet]