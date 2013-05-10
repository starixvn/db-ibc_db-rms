ALTER PROCEDURE [dbo].[RMS_CustomerSel]
	@username	nvarchar(100) = null,
	@level		int	= null
AS
	/*
		Created: Johnson
		Date: 20121024
		Task: Get customer info by @username and @level
		DB: DB054.bodb_RMS
		
		Revisions:
		
		Parameter's Explanation:
	*/ 
SET NOCOUNT ON 

	SELECT 
		custid
		,username
		,[level]		
	FROM rmCustomer mc WITH(NOLOCK)
	WHERE username = ISNULL(@username,username)
		AND level = ISNULL(@level,level)
	ORDER BY username ASC


GO
GRANT EXECUTE ON [dbo].[RMS_CustomerSel] TO [bodbRMSNet]