/*<info serverAlias="DBRMS-bodb_RMS" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[RMS_ManageAlert_SelectAlert]
	@AlertTime DATETIME,
	@AlertType SMALLINT,
	@Member NVARCHAR(50),
	@CheckBy NVARCHAR(50),
	@ActionType SMALLINT,
	@TicketStatus SMALLINT

AS
/*
	Created by: 20230620@Cherry.Dang
	Task : Manage Alert Letstalk on PRMS
	DB: DBRMS/bodb_RMS
	
	Revisions:		
		20230620@Cherry: Initial (#189147)

	Param:
		@AlertType = 1: Similar Bet
				   = 2: Small Odds
				   = 3: Potential Winning
				   = 4: Last Pending Tickets
				   = 5: Small League & Odds
		@ActionType = 0: No Action
					= 1: Send S&V
					= 2: Send OS
					= 3: Take Note
		@TicketStatus = 112: Won
					  = 113: Lose
					  = 0: Running

*/

BEGIN
	SET NOCOUNT ON

	CREATE TABLE #tmpAlert
	(
		[AlertTime] [DATETIME],
		[TransID] [BIGINT],
		[CustID] [INT],
		[AlertType] [SMALLINT],
		[CheckBy] [INT],
		[AlertAction] [SMALLINT] DEFAULT(0),
		[TransInfo] VARBINARY(MAX),
		[IsTest] BIT 
	)
	
	DECLARE @TransList VARCHAR(MAX), @TransID BIGINT, @CustID INT, @AlertID BIGINT
	CREATE TABLE #tmpTransID (TransID BIGINT)
	
	BEGIN TRY
		BEGIN TRANSACTION
			SELECT @TransList = tl
			FROM  OPENJSON (CAST( DECOMPRESS(@TransInfo) AS NVARCHAR(MAX)))
			WITH (
				tl VARCHAR(MAX)
				)

			INSERT INTO #tmpTransID (TransID)
			SELECT val
			FROM bodb02.dbo.strSplit(@TransList, ',')

			SELECT @TransID = MAX(TransID)
			FROM #tmpTransID

			SELECT @CustID = t.CustID
			FROM (
				SELECT custid 
				FROM dbo.rmBettrans WITH(NOLOCK)
				WHERE transid = @TransID
				UNION
				SELECT custid 
				FROM dbo.rmBettrans_Old WITH(NOLOCK)
				WHERE transid = @TransID
			) t		

			INSERT INTO dbo.rmAlert (AlertTime, TransID, CustID, AlertType, TransInfo, IsTest)
			SELECT @AlertTime, @TransID, @CustID, @AlertType, @TransInfo, @IsTest

			SELECT @AlertID = IDENT_CURRENT('rmAlert')

			INSERT INTO dbo.rmAlertDetail (AlertID, RefType, RefValInt)
			SELECT @AlertID, 1, TransID
			FROM #tmpTransID

		COMMIT TRANSACTION
	END TRY
	BEGIN CATCH
		SELECT @ErrorMsg = error_message()
		ROLLBACK TRANSACTION
	END CATCH

END 
 

