
/*<info serverAlias="DBRMS-bodb_RMS" executers="wsv_rms" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[RMS_PotentialWinningAlertIns] @CustId      INT, 
                                                     @AlertAmount MONEY, 
                                                     @IsSMP  INT

													 
/*
	Created: Jacob
	Date: 2020-02-07
	Task: Notify/Alert by Winning Amount
	DB: DBRMS/bodb_RMS


Revisions:
	- 20200207@Jacob: Notify/Alert by Winning Amount #128093
	- 20240312@Cherry: Change SQL account in metadata (#202012)
*/

AS
     SET NOCOUNT ON;
     INSERT INTO [dbo].[rmPotentialWinningAlert]
     ([CustId], 
      [AlertTime], 
      [AlertAmount], 
      [IsSMP]
     )
     VALUES
     (@CustId, 
      GETDATE(), 
      @AlertAmount, 
      @IsSMP
     );
GO