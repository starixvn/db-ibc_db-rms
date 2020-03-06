/*<info serverAlias="DBRMS-bodb_RMS" executers="bodbRMSNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[RMS_Monitor_Parlay_AbnormalBetAlert]
AS

/*
	Created: 20200306@Percy
	DB: DBRMS-bodb_RMS
	Task: Parlay RMS - Get duplicate match in sub tickets for letstalk

	Revisions:
		- 20200306@Percy: Initialize SP [RedmineID: #129944]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @LastTransDate DATETIME, @TransDate DATETIME
	SELECT	@LastTransDate = bodb02.dbo.f_Get_SystemSettings('AbnormalBetAlert_LastTransDate')
	SELECT  @TransDate = MAX(TransDate) FROM dbo.rmBettrans WITH (NOLOCK)

	IF @LastTransDate IS NULL
		SET @LastTransDate = CONVERT(DATE, GETDATE()) -- from begin today

	SELECT TransId, Username
	FROM (
		SELECT b.TransId, b.Username, bm.matchid
		FROM dbo.rmBettrans b WITH (NOLOCK)
			INNER JOIN bodb02.dbo.bettransm bm WITH (NOLOCK) ON bm.refno = b.refno
		WHERE b.TransDate > @LastTransDate
			AND b.matchid = 29
			AND b.statusID IN (0, 1, 111, 112, 113)
			AND b.currency <> 20
		GROUP BY b.transid, b.Username, bm.matchid
		HAVING COUNT(1) > 1
	) r
	GROUP BY TransId, Username
	ORDER BY TransId

	SELECT @TransDate AS TransDate -- new TransDate
END
GO