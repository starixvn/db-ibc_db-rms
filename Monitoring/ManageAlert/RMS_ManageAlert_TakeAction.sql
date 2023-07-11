/*<info serverAlias="DBRMS-bodb_RMS" executers="bodbRMSNet" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[RMS_ManageAlert_TakeAction]
	@AlertID BIGINT,
	@UserID INT,
	@IsChecked BIT,
	@ActionID SMALLINT,
	@ErrorMsg VARCHAR(MAX) = '' OUTPUT
AS
/*
	Created by: 20230620@Cherry.Dang
	Task : Manage Alert Letstalk on PRMS
	DB: DBRMS/bodb_RMS
	
	Revisions:		
		20230620@Cherry: Initial (#189147)

	Param:
		@IsChecked = 1: Checked By
				   = 0: Change Action

*/

BEGIN
	SET NOCOUNT ON
	
	BEGIN TRY
		BEGIN TRANSACTION
			INSERT INTO dbo.rmAlertLog 
			(
				LogTime,
				AlertID,
				UserID,
				ActionID
			)
			SELECT
				GETDATE(),
				@AlertID,
				@UserID,
				@ActionID

			IF @IsChecked = 1 AND @ActionID = 4
			BEGIN				
				UPDATE dbo.rmAlert WITH(ROWLOCK, UPDLOCK)
				SET CheckBy = @UserID
				WHERE AlertID = @AlertID
			END

			IF @IsChecked = 0 
			BEGIN
				UPDATE dbo.rmAlert WITH(ROWLOCK, UPDLOCK)
				SET AlertAction = @ActionID
				WHERE AlertID = @AlertID
			END
		COMMIT TRANSACTION
	END TRY
	BEGIN CATCH
		SELECT @ErrorMsg = error_message()
		ROLLBACK TRANSACTION
	END CATCH

END 
 

