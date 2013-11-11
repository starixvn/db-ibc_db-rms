 ALTER PROCEDURE [dbo].[RMS_DangerousAgentSel]
	@username NVARCHAR(50)= NULL
AS
	/*
		Created: Johnson
		Date: 2013-11-11
		Task: Get list dangerous agents
		DB: DBRMS/bodb_RMS
		
		Revisions:
		
		Parameter's Explanation:
	*/
BEGIN
	SET NOCOUNT ON
	
	SELECT agentid, username
	FROM rmAgent WITH(NOLOCK)
	WHERE username LIKE '%'+ ISNULL(@username,username) + '%' 
	
END
GO
GRANT EXECUTE ON [dbo].[RMS_DangerousAgentSel] TO [bodbRMSNet]