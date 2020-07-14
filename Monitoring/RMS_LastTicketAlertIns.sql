/*<info serverAlias="DBRMS-bodb_RMS" executers="bodbRMSNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[RMS_LastTicketAlertIns]
	@TransId		BIGINT
	,@AlertAmount	MONEY = 0
	,@ParlayType	NVARCHAR(50) = ''
	,@JobType		TINYINT = 1
AS

/*
	Created: Franklin
	Date: 2020-02-26
	DB: DBRMS/bodb_RMS
	Task: Notify/Alert by Winning Amount
	
	Revisions:
		- 20200226@Franklin: Notify/Alert by Winning Amount #129275
		- 20200703@Percy: Add jobtype to support many jobs [RedmineID: #137010]
*/

BEGIN
	SET NOCOUNT ON

	INSERT INTO dbo.rmLastTicketAlert (TransId,AlertTime,AlertAmount,ParlayType,JobType)
    VALUES (@TransId, GETDATE(), @AlertAmount, @ParlayType, @JobType)

	DELETE rmLastTicketAlert WITH (ROWLOCK, UPDLOCK)
	WHERE AlertTime < DATEADD(MONTH, -1, GETDATE())
END
GO