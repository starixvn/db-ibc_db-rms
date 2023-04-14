/*<info serverAlias="DBRMS-bodb_RMS" executers="bodbRMSNet" isFunction="0" isNested="0"></info>*/
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
			- 20230412@Cherry: Add Site column (#186735)
		
		Parameter's Explanation:
	*/ 
SET NOCOUNT ON 

	SELECT 
		mc.custid
		,CASE WHEN s.isDeposit = 0 OR s.site = 'Saba789' THEN 'C' ELSE 'L' END SiteGroup
		,mc.username
		,mc.[level]		
	FROM rmCustomer mc WITH(NOLOCK)
		INNER JOIN bodb02.dbo.customer c WITH(NOLOCK) ON mc.custid = c.custid
		INNER JOIN bodb02.dbo.site s WITH(NOLOCK) ON c.site = s.site
	WHERE mc.username like '%' + ISNULL(@username,mc.username) + '%'
		AND level = ISNULL(@level,mc.level)
	ORDER BY mc.username ASC


GO
