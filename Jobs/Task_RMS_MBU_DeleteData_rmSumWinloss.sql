/*<info serverAlias="DBRMS-bodb_RMS" isFunction="0" isNested="1"></info>*/
CREATE PROCEDURE [dbo].[Task_RMS_MBU_DeleteData_rmSumWinloss]
	@winlostdate SMALLDATETIME
	,@ErrCode		INT = 0 OUTPUT
	,@ErrMsg		VARCHAR(4000) = '' OUTPUT
AS

/*
	Created: 20200512@Percy
	DB: DBRMS-bodb_RMS
	Task: RMS - Delete data from rmSumWinloss

	Revisions:
		- 20200512@Percy: Initialize SP [RedmineID: #130275]
		- 20201214@Danny: Separate Data of Virtual Soccer & Virtual Basketball [RedmineID: #145926]
*/

BEGIN
	SET NOCOUNT ON

	BEGIN TRY
		IF EXISTS (SELECT 1 FROM dbo.rmSumWinloss WITH (NOLOCK) WHERE winlostdate = @winlostdate)
			DELETE dbo.rmSumWinloss WITH (ROWLOCK, UPDLOCK) WHERE winlostdate = @winlostdate
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = 101, @ErrMsg = ERROR_MESSAGE()
		RETURN
	END CATCH
END
GO