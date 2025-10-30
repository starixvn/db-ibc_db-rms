
/*<info serverAlias="DBRMS-bodb_RMS" executers="wsv_rms" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[RMS_PotentialWinningAlertIns] 
	@CustId INT, 
    @AlertAmount MONEY, 
    @IsSMP BIT = 0,
	@IsHP BIT = 0

													 
/*
	Created: Jacob
	Date: 2020-02-07
	Task: Notify/Alert by Winning Amount
	DB: DBRMS/bodb_RMS


Revisions:
	- 20200207@Jacob: Notify/Alert by Winning Amount #128093
	- 20240312@Cherry: Change SQL account in metadata (#202012)
	- 20251030@Cherry: Add Hybrid Parlay (#242165)
*/

AS
     SET NOCOUNT ON;
     INSERT INTO [dbo].[rmPotentialWinningAlert]
     ([CustId], 
      [AlertTime], 
      [AlertAmount], 
      [IsSMP],
	  [IsHP]
     )
     VALUES
     (@CustId, 
      GETDATE(), 
      @AlertAmount, 
      @IsSMP,
	  @IsHP
     );
GO