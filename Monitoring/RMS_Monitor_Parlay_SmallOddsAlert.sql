/*<info serverAlias="DBRMS-bodb_RMS" executers="bodbRMSNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[RMS_Monitor_Parlay_SmallOddsAlert]
	@IsTest BIT = 0
AS

/*
	Created: 20200703@Percy
	DB: DBRMS-bodb_RMS
	Task: Parlay RMS - Get parlay tickets which small odds for letstalk

	Revisions:
		- 20200703@Percy: Initialize SP [RedmineID: #137010]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @LastTransDate DATETIME, @TransDate DATETIME
	SELECT	@LastTransDate = bodb02.dbo.f_Get_SystemSettings('SmallOddsAlert_LastTransDate')
	SELECT  @TransDate = MAX(TransDate) FROM dbo.rmBettrans WITH (NOLOCK)

	IF @LastTransDate IS NULL
		SET @LastTransDate = CONVERT(DATE, GETDATE()) -- from begin today
	ELSE
		SET @LastTransDate = DATEADD(HOUR, -1, @LastTransDate)

	SELECT
		b.TransId
		,CASE WHEN b.betteam = N'1' THEN 'Mix Parlay' ELSE 'Combo Parlay' END AS ParlayType
		,b.Username
		,e.currency
		,b.stake * CASE WHEN @IsTest = 1 THEN 1 ELSE b.actualrate END AS stake
		,(b.odds2 - 1) * b.stake * CASE WHEN @IsTest = 1 THEN 1 ELSE b.actualrate END AS WinningAmount
		,(b.odds2 - 1) * b.stake * CASE WHEN @IsTest = 1 THEN 1 ELSE b.actualrate END * (1 - b.tpositiontaking) AS CompanyLoseAmount
		,b.hdp2 AS Selection
		,b.odds2 AS odds
		,1 - b.tpositiontaking AS HousePT
	FROM dbo.rmBettrans b WITH (NOLOCK)
		CROSS APPLY (
			SELECT TOP 1 bm.transid
			FROM bodb02.dbo.bettransm bm WITH (NOLOCK)
			WHERE bm.refno = b.refno
				AND bm.odds <= 1.1
		) bm
		INNER JOIN bodb02.dbo.Exchange e WITH (NOLOCK) ON b.currency = e.exchangeid
	WHERE b.TransDate > @LastTransDate
		AND b.matchid = 29
		AND b.statusID = 0
		AND b.stake * CASE WHEN @IsTest = 1 THEN 1 ELSE b.actualrate END >= 10000
		AND NOT EXISTS (SELECT 1 FROM dbo.rmLastTicketAlert t WITH (NOLOCK) WHERE b.transid = t.transid AND t.JobType = 2)

	SELECT CONVERT(VARCHAR(200), @TransDate, 121) AS TransDate -- new TransDate
END
GO