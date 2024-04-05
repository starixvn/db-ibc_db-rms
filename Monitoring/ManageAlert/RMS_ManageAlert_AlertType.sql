/*<info serverAlias="DBRMS-bodb_RMS" executers="wsv_rms" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[RMS_ManageAlert_AlertType]
AS
/*
	Created by: 20230620@Cherry.Dang
	Task : Manage Alert Letstalk on PRMS
	DB: DBRMS/bodb_RMS
	
	Revisions:		
		20230620@Cherry: Initial (#189147)
		20240312@Cherry: Change SQL account in metadata (#202012)

*/

BEGIN
	SET NOCOUNT ON
	SELECT AlertTypeID, AlertTypeName
	FROM bodb_RMS.dbo.rmAlertType WITH(NOLOCK)
END 
 

