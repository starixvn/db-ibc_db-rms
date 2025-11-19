/*<info serverAlias="DBRMS-bodb_RMS" isFunction="0" isNested="1"></info>*/
CREATE PROCEDURE [dbo].[Task_RMS_MBU_DeleteData_rmBettransm_bk]
	@winlostdate SMALLDATETIME
	,@ErrCode		INT = 0 OUTPUT
	,@ErrMsg		VARCHAR(4000) = '' OUTPUT
AS

/*
	Created: 20210319@Danny
	DB: DBRMS-bodb_RMS
	Task: RMS - Delete data from rmBettransm_bk

	Revisions:
		- 20210319@Danny: Initialize SP [RedmineID: #151319]
*/

BEGIN
	SET NOCOUNT ON

	BEGIN TRY
		IF EXISTS (SELECT 1 FROM dbo.rmBettransm_bk WITH (NOLOCK) WHERE winlostdate = @winlostdate)
		BEGIN
			DELETE dbo.rmBettransm_bk WITH (ROWLOCK, UPDLOCK) WHERE winlostdate = @winlostdate
		END

		IF EXISTS (SELECT 1 FROM dbo.rmMatch_bk WITH (NOLOCK) WHERE eventdate = @winlostdate)
		BEGIN
			DELETE dbo.rmMatch_bk  WITH (ROWLOCK, UPDLOCK) WHERE eventdate = @winlostdate
		END
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = 101, @ErrMsg = ERROR_MESSAGE()
		RETURN
	END CATCH
END
GO