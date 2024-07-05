/*<info serverAlias="DBRMS-bodb_RMS" executers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Task_RMS_DeleteData]

AS
/*
	Created by: 20230801@Cherry.Dang
	Task : Manage Alert Letstalk on PRMS
	DB: DBRMS/bodb_RMS
	
	Revisions:		
		20230620@Cherry: Initial (#189147)
		20240705@Cherry: Add to delete rmMajorBettypeAlert (#202238)

*/

BEGIN
	SET NOCOUNT ON

	DECLARE @ToDate DATETIME, @MaxAlertID BIGINT
	SELECT @ToDate = DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()) - 3, 0)

	SELECT @MaxAlertID = MAX(AlertID)
	FROM dbo.rmAlert WITH(NOLOCK)
	WHERE AlertTime < @ToDate

	IF @MaxAlertID IS NULL
		RETURN

	DELETE dbo.rmAlert WITH (ROWLOCK, UPDLOCK) 
	WHERE AlertTime < @ToDate

	DELETE dbo.rmAlertDetail WITH (ROWLOCK, UPDLOCK) 
	WHERE AlertID <= @MaxAlertID

	DELETE dbo.rmAlertLog WITH (ROWLOCK, UPDLOCK) 
	WHERE AlertID <= @MaxAlertID

	SELECT @MaxAlertID = MAX(AlertID)
	FROM dbo.rmMajorBettypeAlert WITH(NOLOCK)
	WHERE AlertTime < @ToDate

	IF @MaxAlertID IS NULL
		RETURN

	DELETE dbo.rmMajorBettypeAlert WITH (ROWLOCK, UPDLOCK) 
	WHERE AlertID <= @MaxAlertID

END 
 

