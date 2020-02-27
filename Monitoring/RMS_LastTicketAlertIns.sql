
/*<info serverAlias="DBRMS-bodb_RMS" executers="bodbRMSNet" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[RMS_LastTicketAlertIns] @TransId     BIGINT, 
                                               @AlertAmount MONEY, 
                                               @IsSMP       INT

/*
	Created: Franklin
	Date: 2020-02-26
	Task: Notify/Alert by Winning Amount
	DB: DBRMS/bodb_RMS


Revisions:
- 20200226@Franklin: Notify/Alert by Winning Amount #129275
*/

AS
     SET NOCOUNT ON;
     INSERT INTO [dbo].[rmLastTicketAlert]
     ([TransId], 
      [AlertTime], 
      [AlertAmount], 
      [IsSMP]
     )
     VALUES
     (@TransId, 
      GETDATE(), 
      @AlertAmount, 
      @IsSMP
     );
GO