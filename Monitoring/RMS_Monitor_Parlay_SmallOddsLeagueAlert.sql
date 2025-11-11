/*<info serverAlias="DBRMS-bodb_RMS" executers="wsv_rms" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[RMS_Monitor_Parlay_SmallOddsLeagueAlert]
	@IsTest BIT = 0
AS

/*
	Created: 20200703@Percy
	DB: DBRMS-bodb_RMS
	Task: Parlay RMS - Get mix parlay tickets which small odds, league for letstalk

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

	DECLARE @rmLeague TABLE (leagueId INT)
	INSERT INTO @rmLeague (leagueId)
	SELECT l.LeagueId
	FROM dbo.rmLeague l WITH (NOLOCK)
		INNER JOIN dbo.rmLeagueGroup lg WITH (NOLOCK) ON l.GroupId = lg.GroupId
	WHERE lg.GroupName IN ('m3','m4 (a)','m4 (b)','m4 (x)')

	DECLARE @LastTransDate DATETIME, @TransDate DATETIME
	SELECT	@LastTransDate = dbo.f_RMS_rmSettings('SmallOddsLeagueAlert_LastTransDate')
	SELECT  @TransDate = MAX(TransDate) FROM dbo.rmBettrans WITH (NOLOCK)

	IF @LastTransDate IS NULL
		SET @LastTransDate = CONVERT(DATE, GETDATE()) -- from begin today
	ELSE
		SET @LastTransDate = DATEADD(HOUR, -1, @LastTransDate)

	CREATE TABLE #tmpHybrid (transid BIGINT)

	INSERT INTO #tmpHybrid (transid)
	SELECT transid
	FROM dbo.rmBettrans WITH (NOLOCK)
	WHERE TransDate > @LastTransDate
		AND bettype = 29
		AND betteam = N'1'
		AND oddsspread = 3
		AND statusID = 0
		AND ((@IsTest = 0 AND currency <> 20) 
			OR (@IsTest = 1 AND currency = 20)
			)

	-- Mix parlay tickets have 2 selections
	-- 1. 1 selection: on small league
	DECLARE @bettrans TABLE (transid BIGINT, refno BIGINT, m_transid BIGINT)
	INSERT INTO @bettrans (transid, refno, m_transid)
	SELECT b.TransId, b.refno, bm.transid
	FROM dbo.rmBettrans b WITH (NOLOCK)
		CROSS APPLY (
			SELECT TOP 1 bm.transid
			FROM bodb02.dbo.bettransm bm WITH (NOLOCK)
				INNER JOIN bodb02.dbo.match m WITH (NOLOCK) ON bm.matchid = m.matchid
			WHERE bm.refno = b.refno
				AND EXISTS (SELECT 1 FROM @rmLeague l WHERE m.leagueid = l.leagueId)
			ORDER BY CASE WHEN bm.bettype IN (5, 15) THEN 1 ELSE 0 END
		) bm
	WHERE b.TransDate > @LastTransDate
		AND b.matchid = 29
		AND b.betteam = N'1'
		AND b.hdp2 = 2
		AND b.statusID = 0
		AND ((@IsTest = 0 AND b.currency <> 20) 
			OR (@IsTest = 1 AND b.currency = 20)
			)
		AND (b.odds2 - 1) * b.stake * CASE WHEN @IsTest = 1 THEN 1 ELSE b.actualrate END >= 10000
		AND b.odds2 BETWEEN 1.01 AND 1.20
		AND NOT EXISTS (SELECT 1 FROM dbo.rmLastTicketAlert t WITH (NOLOCK) WHERE b.transid = t.transid AND t.JobType = 3)

	-- 2. Remaining selection: FT/HT 1x2
	DELETE b
	FROM @bettrans b
	WHERE NOT EXISTS (
			SELECT 1
			FROM bodb02.dbo.bettransm bm WITH (NOLOCK)
			WHERE bm.refno = b.refno
				AND bm.bettype IN (5, 15)
				AND bm.transid <> b.m_transid
		)

	CREATE TABLE #Result
	(
		TransId BIGINT,
		Username NVARCHAR(50),
		currency NVARCHAR(50),
		WinningAmount MONEY,
		CompanyLoseAmount MONEY,
		odds SMALLMONEY,
		HousePT SMALLMONEY,
		ParlayType VARCHAR(50),
		TotalSelection INT,
		TotalBets INT,
		Stake MONEY
	)

	INSERT INTO #Result
	(
		TransId,
		Username,
		currency,
		WinningAmount,
		CompanyLoseAmount,
		odds,
		HousePT,
		ParlayType,
		TotalSelection,
		TotalBets,
		Stake 
	)
	SELECT
		b.TransId,
		b.Username,
		e.currency,
		(b.odds2 - 1) * b.stake * CASE WHEN @IsTest = 1 THEN 1 ELSE b.actualrate END AS WinningAmount,
		(b.odds2 - 1) * b.stake * CASE WHEN @IsTest = 1 THEN 1 ELSE b.actualrate END * (1 - b.tpositiontaking) AS CompanyLoseAmount,
		b.odds2 AS odds,
		(1 - b.tpositiontaking) AS HousePT,
		CASE WHEN b.betteam = N'1' 
				AND ISNULL(TRY_CAST(TRY_CAST(b.ExtraInfo AS XML).value('(/p1/@bac)[1]', 'VARCHAR(50)') AS INT),0)|16 = ISNULL(TRY_CAST(TRY_CAST(b.ExtraInfo AS XML).value('(/p1/@bac)[1]', 'VARCHAR(50)') AS INT),0) 
				THEN 'Parlay Generator' 
			WHEN b.betteam = N'1' THEN 'Mix Parlay' 
			ELSE 'Combo Parlay' END AS ParlayType,
		b.hdp2 AS TotalSelection,
		b.TotalBet,
		b.stake * CASE WHEN @IsTest = 1 THEN 1 ELSE b.actualrate END AS stake
	FROM dbo.rmBettrans b WITH (NOLOCK)
		INNER JOIN bodb02.dbo.Exchange e WITH (NOLOCK) ON b.currency = e.exchangeid
	WHERE EXISTS (SELECT 1 FROM @bettrans bt WHERE b.transid = bt.transid)
		AND NOT EXISTS (SELECT 1 FROM #tmpHybrid h WHERE b.transid = h.transid)

	SELECT
		TransId,
		Username,
		currency,
		WinningAmount,
		CompanyLoseAmount,
		odds,
		HousePT,
		COMPRESS((SELECT CAST(t.TransId AS VARCHAR) AS 'tl',
					t.ParlayType AS 'sp',
					CAST(t.TotalSelection AS VARCHAR) AS 'sl',
					t.Odds AS 'od',
					t.TotalBets AS 'tb',
					t.Stake AS 'ms',
					t.WinningAmount AS 'pw',
					t.CompanyLoseAmount AS 'pl'
				FROM #result t
				WHERE t.TransId = d.TransId 
					FOR JSON PATH
					,INCLUDE_NULL_VALUES
				)) TransInfo
	FROM #Result d

	SELECT CONVERT(VARCHAR(200), @TransDate, 121) AS TransDate -- new TransDate

	DROP TABLE #Result
	DROP TABLE #tmpHybrid

END
GO