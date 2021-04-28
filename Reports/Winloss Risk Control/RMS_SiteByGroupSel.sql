/*<info serverAlias="DBRMS-bodb_RMS" executers="bodbRMSNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[RMS_SiteByGroupSel]
	@IsDeposit BIT = ''
AS

/*
	Created: 20201030@Danny
	DB: DBRMS-bodb_RMS
	Task: report winloss risk control
		
	Revisions:	
		- 20201030@Danny: Initialize SP [RedmineID: #144471]		
	

*/

BEGIN
	SET NOCOUNT ON

	SELECT Site, CASE WHEN Site = 'Saba789' THEN 0 ELSE isDeposit  END  isDeposit
	FROM bodb02.dbo.Site WITH(NOLOCK)
	WHERE isDeposit = CASE WHEN @IsDeposit= '' THEN isDeposit ELSE @IsDeposit END
	AND isActive = 1
	ORDER BY isDeposit, Site

END
GO

