/*<info serverAlias="DBRMS-bodb_RMS" executers="bodbRMSNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[RMS_Monitor_Parlay_BigWinningAlert]
	@IsTest BIT = 0
AS

/*
	Created: 20230404@Cherry
	DB: DBRMS-bodb_RMS
	Task: Parlay RMS - Get parlay tickets which big winning for letstalk

	Revisions:
		- 20230404@Cherry: Initialize SP [RedmineID: #186037]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @min_tstamp BINARY(8), @max_tstamp BINARY(8)
	SELECT  @min_tstamp = CONVERT(BINARY(8), CONVERT(BIGINT, ISNULL(VValue, 0)) + 1)
	FROM dbo.rmSettings WITH (ROWLOCK)
	WHERE VName = 'BigWinningAlert_LastTstamp'

	SELECT  @max_tstamp = MAX(tstamp) FROM bodb02.dbo.bettrans WITH (NOLOCK)

	SELECT
		b.TransId
		
	FROM bodb02.dbo.bettrans b WITH (NOLOCK)
		INNER JOIN bodb02.dbo.Exchange e WITH (NOLOCK) ON b.currency = e.exchangeid
	WHERE b.tstamp between @min_tstamp and @max_tstamp
		AND b.bettype IN (29, 38)
		AND b.statusID = 112
		AND b.currency <> 20
		AND (b.winlost - b.actual_stake) * b.actualrate >= 65000
		AND NOT EXISTS (SELECT 1 FROM dbo.rmLastTicketAlert t WITH (NOLOCK) WHERE b.transid = t.transid AND t.JobType = 4)

	SELECT CONVERT(VARCHAR(200), CONVERT(BIGINT, @max_tstamp)) AS Tstamp
	
END
GO