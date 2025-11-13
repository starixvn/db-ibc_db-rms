/*<info serverAlias="DBRMS-bodb_RMS" executers="wsv_rms" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[RMS_Monitor_Parlay_SmallOddsAlert]
	@IsTest BIT = 0
AS

/*
	Created: 20200703@Percy
	DB: DBRMS-bodb_RMS
	Task: Parlay RMS - Get parlay tickets which small odds for letstalk

	Revisions:
		- 20200703@Percy: Initialize SP [RedmineID: #137010]
		- 20230620@Cherry: Manage Alert (#189147)
		- 20231101@Cherry: Parlay Generator (#195498)
		- 20240115@Cherry: Change attribute for Parlay Generator (#199766)
		- 20240312@Cherry: Change SQL account in metadata (#202012)
		- 20250604@Cherry: Show Total Selection as INT (#229589)
		- 20251120@Cherry: Exclude Hybrid Parlay (#242165)
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @LastTransDate DATETIME, @TransDate DATETIME
	SELECT	@LastTransDate = dbo.f_RMS_rmSettings('SmallOddsAlert_LastTransDate')
	SELECT  @TransDate = MAX(TransDate) FROM dbo.rmBettrans WITH (NOLOCK)

	IF @LastTransDate IS NULL
		SET @LastTransDate = CONVERT(DATE, GETDATE()) -- from begin today
	ELSE
		SET @LastTransDate = DATEADD(HOUR, -1, @LastTransDate)

	CREATE TABLE #Result
	(
		TransId BIGINT,
		ParlayType VARCHAR(50),
		Username NVARCHAR(50),
		currency NVARCHAR(50),
		stake MONEY,
		WinningAmount MONEY,
		CompanyLoseAmount MONEY,
		Selection INT,
		odds SMALLMONEY,
		HousePT SMALLMONEY,
		TotalBets INT
	)

	CREATE TABLE #tmpBettrans (transid BIGINT, bac INT)

	INSERT INTO #tmpBettrans (transid, bac)
	SELECT transid,
		ISNULL(TRY_CAST(TRY_CAST(ExtraInfo AS XML).value('(/p1/@bac)[1]', 'VARCHAR(50)') AS INT),0)
	FROM dbo.rmBettrans WITH (NOLOCK)
	WHERE TransDate > @LastTransDate
		AND matchid = 29
		AND statusID = 0
		AND ((@IsTest = 0 AND currency <> 20) 
			OR (@IsTest = 1 AND currency = 20)
			)

	INSERT INTO #Result
	(
		TransId,
		ParlayType,
		Username,
		currency,
		stake,
		WinningAmount,
		CompanyLoseAmount,
		Selection,
		odds,
		HousePT,
		TotalBets 
	)
	SELECT
		b.TransId,
		CASE WHEN b.betteam = N'1' AND t.bac|16 = t.bac THEN 'Parlay Generator'
			WHEN b.betteam = N'1' THEN 'Mix Parlay' 
			ELSE 'Combo Parlay' END AS ParlayType,
		b.Username,
		e.currency,
		b.stake * CASE WHEN @IsTest = 1 THEN 1 ELSE b.actualrate END AS stake,
		(b.odds2 - 1) * b.stake * CASE WHEN @IsTest = 1 THEN 1 ELSE b.actualrate END AS WinningAmount,
		(b.odds2 - 1) * b.stake * CASE WHEN @IsTest = 1 THEN 1 ELSE b.actualrate END * (1 - b.tpositiontaking) AS CompanyLoseAmount,
		b.hdp2 AS Selection,
		b.odds2 AS odds,
		1 - b.tpositiontaking AS HousePT,
		b.TotalBet
	FROM dbo.rmBettrans b WITH (NOLOCK)
		CROSS APPLY (
			SELECT TOP 1 bm.transid
			FROM bodb02.dbo.bettransm bm WITH (NOLOCK)
			WHERE bm.refno = b.refno
				AND bm.odds <= 1.1
		) bm
		INNER JOIN bodb02.dbo.Exchange e WITH (NOLOCK) ON b.currency = e.exchangeid
		LEFT JOIN #tmpBettrans t ON b.transid = t.transid
	WHERE b.TransDate > @LastTransDate
		AND b.matchid = 29
		AND b.statusID = 0
		AND ((@IsTest = 0 AND b.currency <> 20) 
			OR (@IsTest = 1 AND b.currency = 20)
			)
		AND b.stake * CASE WHEN @IsTest = 1 THEN 1 ELSE b.actualrate END >= 10000
		AND NOT EXISTS (SELECT 1 FROM dbo.rmLastTicketAlert t WITH (NOLOCK) WHERE b.transid = t.transid AND t.JobType = 2)
		AND NOT EXISTS (SELECT 1 FROM dbo.rmBettrans h WITH (NOLOCK) WHERE b.transid = h.transid AND h.bettype = 29 AND h.betteam = N'1' AND h.oddsspread = 3)

	SELECT d.TransId,
		d.ParlayType,
		d.Username,
		d.currency,
		d.stake,
		d.WinningAmount,
		d.CompanyLoseAmount,
		d.Selection,
		d.odds,
		d.HousePT,
		COMPRESS((SELECT CAST(TransId AS VARCHAR) AS 'tl',
					ParlayType AS 'sp',
					CAST(Selection AS VARCHAR) AS 'sl',
					Odds AS 'od',
					TotalBets AS 'tb',
					stake AS 'ms',
					WinningAmount AS 'pw',
					CompanyLoseAmount AS 'pl'
				FROM #result t
				WHERE t.TransId = d.TransId 
					FOR JSON PATH
					,INCLUDE_NULL_VALUES
				)) TransInfo
	FROM #Result d

	SELECT CONVERT(VARCHAR(200), @TransDate, 121) AS TransDate

	DROP TABLE #Result
	DROP TABLE #tmpBettrans

END
GO