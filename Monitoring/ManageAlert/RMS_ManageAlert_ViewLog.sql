/*<info serverAlias="DBRMS-bodb_RMS" executers="bodbRMSNet" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[RMS_ManageAlert_ViewLog]
	@AlertID BIGINT

AS
/*
	Created by: 20230620@Cherry.Dang
	Task : Manage Alert Letstalk on PRMS
	DB: DBRMS/bodb_RMS
	
	Revisions:		
		20230620@Cherry: Initial (#189147)

	Param:

*/

BEGIN
	SET NOCOUNT ON
	
	SELECT l.LogTime,
			a.ActionName,
			c.username UserName
	FROM dbo.rmAlertLog l WITH(NOLOCK)
		INNER JOIN dbo.rmAlertAction a WITH(NOLOCK) ON l.ActionID = a.ActionID
		INNER JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON l.UserID = c.custid
	WHERE l.AlertID = @AlertID

END 
 

