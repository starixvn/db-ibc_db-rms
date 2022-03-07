/*<info serverAlias="DBRMS-bodb_RMS" executers="bodbRMSNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[RMS_SelBalanceUpDay]
AS
	/*
		Created: Johnson
		Date: 2012-11-08
		Task: Get move bets day and balance up day for RMS
		DB: DB054.bodb_RMS
		
		Revisions:
			- 20220307@Danny: Change SP get MBU date [RedmineID: #164547]	
		
		Parameter's Explanation: 
	*/ 
SET NOCOUNT ON

	EXEC bodb02.dbo.Age_SelBalanceUpDay

GO