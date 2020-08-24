/*<info serverAlias="DBRMS-bodb_RMS" executers="bodbRMSNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[RMS_rmSettings_Upd]
	@VName		VARCHAR(100)
	,@VValue	VARCHAR(500)
AS

/*
	Created: 20200703@Percy
	DB: DBRMS-bodb_RMS
	Task: Parlay RMS - rmSettings - Update

	Revisions:
		- 20200703@Percy: Initialize SP [RedmineID: #137010]
*/

BEGIN
	SET NOCOUNT ON

	UPDATE dbo.rmSettings WITH (ROWLOCK)
	SET VValue = @VValue
	WHERE VName = @VName

	IF @@ROWCOUNT = 0
		INSERT INTO dbo.rmSettings (VName, VValue)
		VALUES (@VName, @VValue)
END
GO