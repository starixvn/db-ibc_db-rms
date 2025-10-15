/*<info serverAlias="DBRMS-bodb_RMS" executers="wsv_rms" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[RMS_SiteByGroupSel]
	@IsDeposit BIT = ''
AS

/*
	Created: 20201030@Danny
	DB: DBRMS-bodb_RMS
	Task: report winloss risk control
		
	Revisions:	
		- 20201030@Danny: Initialize SP [RedmineID: #144471]		
		- 20240312@Cherry: Change SQL account in metadata (#202012)
		- 20251016@Cherry: Move sites NovaCasino, SEAL888 from Deposit to Credit (#241763)

*/

BEGIN
	SET NOCOUNT ON

	SELECT Site, CASE WHEN Site IN ('Saba789','NovaCasino','SEAL888') THEN 0 ELSE isDeposit  END  isDeposit
	FROM bodb02.dbo.Site WITH(NOLOCK)
	WHERE isDeposit = CASE WHEN @IsDeposit= '' THEN isDeposit ELSE @IsDeposit END
	AND isActive = 1
	ORDER BY isDeposit, Site

END
GO

