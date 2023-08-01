/*<info serverAlias="DBRMS-bodb_RMS" executers="bodbRMSNet" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[RMS_ManageAlert_AlertAction]
AS
/*
	Created by: 20230620@Cherry.Dang
	Task : Manage Alert Letstalk on PRMS
	DB: DBRMS/bodb_RMS
	
	Revisions:		
		20230620@Cherry: Initial (#189147)

*/

BEGIN
	SET NOCOUNT ON
	SELECT ActionID, ActionName
	FROM bodb_RMS.dbo.rmAlertAction WITH(NOLOCK)
	WHERE ActionID <> 4
END 
 

