/*<info serverAlias="DBRMS-bodb_RMS" executers="wsv_rms" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[RMS_ManageAlert_InsertAlert]
	@AlertTime DATETIME,
	@AlertType SMALLINT,
	@TransInfo VARBINARY(MAX),
	@IsTest BIT = 0,
	@ErrorMsg VARCHAR(MAX) = '' OUTPUT
AS
/*
	Created by: 20230620@Cherry.Dang
	Task : Manage Alert Letstalk on PRMS
	DB: DBRMS/bodb_RMS
	
	Revisions:		
		20230620@Cherry: Initial (#189147)
		20240312@Cherry: Change SQL account in metadata (#202012)

	Param:
		@AlertType = 1: Similar Bet
				   = 2: Small Odds
				   = 3: Potential Winning
				   = 4: Last Pending Tickets
				   = 5: Small League & Odds

*/

BEGIN
	SET NOCOUNT ON
	
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

			SELECT @AlertID = AlertID
			FROM dbo.rmAlert WITH(NOLOCK)
			WHERE TransID = @TransID
				AND CustID = @CustID
				AND AlertType = @AlertType
				AND AlertTime = @AlertTime
				AND IsTest = @IsTest

			IF @AlertID IS NOT NULL
			BEGIN
				INSERT INTO dbo.rmAlertDetail (AlertID, RefType, RefValInt)
				SELECT @AlertID, 1, TransID
				FROM #tmpTransID
			END

		COMMIT TRANSACTION
	END TRY
	BEGIN CATCH
		SELECT @ErrorMsg = error_message()
		ROLLBACK TRANSACTION
	END CATCH

	DROP TABLE #tmpTransID
END 
 

