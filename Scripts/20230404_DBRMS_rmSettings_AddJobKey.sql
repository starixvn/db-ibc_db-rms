/*<info serverAlias="DBRMS-bodb_RMS"></info>*/
/*
	Created: 20230404@Cherry
	DB: DBRMS-bodb_RMS
	Task: PRMS - Add new table SystemSettings
*/

use bodb_RMS
go

DECLARE @min_tstamp BINARY(8)

SELECT  @min_tstamp = MIN(tstamp) FROM bodb02.dbo.bettrans WITH (NOLOCK)

INSERT INTO dbo.rmSettings (VName, VValue)
SELECT 'BigWinningAlert_LastTstamp', CONVERT(VARCHAR(200), CONVERT(BIGINT, @min_tstamp)) 

go