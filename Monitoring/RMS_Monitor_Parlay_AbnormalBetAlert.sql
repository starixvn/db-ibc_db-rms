/*<info serverAlias="DBRMS-bodb_RMS" executers="wsv_rms" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[RMS_Monitor_Parlay_AbnormalBetAlert]
AS

/*
	Created: 20200306@Percy
	DB: DBRMS-bodb_RMS
	Task: Parlay RMS - Get duplicate match in sub tickets for letstalk

	Revisions:
		- 20200306@Percy: Initialize SP [RedmineID: #129944]
		- 20201110@Percy: Return sub tickets info to support write log on web [RedmineID: #145069]
		- 20240312@Cherry: Change SQL account in metadata (#202012)
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @LastTransDate DATETIME, @TransDate DATETIME
	SELECT	@LastTransDate = dbo.f_RMS_rmSettings('AbnormalBetAlert_LastTransDate')
	SELECT  @TransDate = MAX(TransDate) FROM dbo.rmBettrans WITH (NOLOCK)

	IF @LastTransDate IS NULL
		SET @LastTransDate = CONVERT(DATE, GETDATE()) -- from begin today

	DECLARE @TransIds TABLE (TransId BIGINT PRIMARY KEY)
	INSERT INTO @TransIds (TransId)
	SELECT TransId FROM dbo.rmBettrans WITH (NOLOCK) WHERE TransDate > @LastTransDate

	DECLARE @Result TABLE (TransId BIGINT, RefNo BIGINT, Username NVARCHAR(50))
	INSERT INTO @Result (TransId, RefNo, Username)
	SELECT TransId, RefNo, Username
	FROM (
		SELECT b.TransId, b.RefNo, b.Username, bm.matchid
		FROM dbo.rmBettrans b WITH (ROWLOCK)
			INNER JOIN @TransIds t ON b.TransId = t.TransId
			INNER JOIN bodb02.dbo.bettransm bm WITH (NOLOCK) ON bm.refno = b.refno
		WHERE b.matchid = 29
			AND b.statusID IN (0, 1, 111, 112, 113)
			AND b.currency <> 20
		GROUP BY b.TransId, b.RefNo, b.Username, bm.matchid
		HAVING COUNT(1) > 1
	) r
	GROUP BY TransId, RefNo, Username

	-- Main tickets
	SELECT TransId, Username FROM @Result

	-- Sub tickets
	SELECT bm.TransId, bm.RefNo, bm.MatchId, r.Username, bm.TransDate 
	FROM bodb02.dbo.bettransm bm WITH (NOLOCK)
		INNER JOIN @Result r ON bm.RefNo = r.RefNo

	SELECT CONVERT(VARCHAR(200), @TransDate, 121) AS TransDate -- new TransDate
END
GO