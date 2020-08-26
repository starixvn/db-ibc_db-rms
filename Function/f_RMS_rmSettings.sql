/*<info serverAlias="DBRMS-bodb_RMS" isFunction="1" isNested="1"></info>*/
ALTER FUNCTION  [dbo].[f_RMS_rmSettings]  
(
	@VName VARCHAR(100)
)
RETURNS VARCHAR(500)
AS

/*
	Created: 20200703@Percy
	DB: DBRMS-bodb_RMS
	Task: Parlay RMS - rmSettings - Get VValue from VName

	Revisions:
		- 20200703@Percy: Initialize function [RedmineID: #137010]
*/

BEGIN
     DECLARE @VValue VARCHAR(500)

	 SELECT  @VValue = VValue FROM dbo.rmSettings WITH (NOLOCK) WHERE VName = @VName
     RETURN @VValue
END
GO