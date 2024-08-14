/*<info serverAlias="DBRMS-bodb_RMS" executers="wsv_rms" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[RMS_Monitor_SingleMatchBigOddsAlert]
	@IsTest BIT = 0
AS

/*
	Created: 20240815@Cherry
	DB: DBRMS-bodb_RMS
	Task: Parlay RMS - Get single match parlay tickets which big odds for letstalk

	Revisions:
		- 20240815@Cherry: Initialize SP [RedmineID: #209293]

*/

BEGIN
	SET NOCOUNT ON

	DECLARE @LastTransDate DATETIME, @TransDate DATETIME
	SELECT	@LastTransDate = dbo.f_RMS_rmSettings('SingleMatchBigOddsAlert_LastTransDate')
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
		Selection SMALLMONEY,
		odds SMALLMONEY,
		HousePT SMALLMONEY,
		TotalBets INT
	)

	CREATE TABLE #tmpBettrans 
		(transid BIGINT, 
		refno BIGINT,
		hdp2 MONEY,
		odds2 MONEY,
		Stake MONEY,
		WinningAmount MONEY)

	CREATE TABLE #tmpBettransm 
		(refno BIGINT, 
		matchid INT, 
		homeid INT, 
		awayid INT, 
		sporttype INT, 
		leagueid INT)

	INSERT INTO #tmpBettrans 
		(transid, 
		refno,
		hdp2,
		odds2,
		Stake,
		WinningAmount)
	SELECT transid,
		refno,
		hdp2,
		odds2,
		stake * CASE WHEN @IsTest = 1 THEN 1 ELSE actualrate END Stake,
		(b.odds2 - 1) * b.stake * CASE WHEN @IsTest = 1 THEN 1 ELSE b.actualrate END AS WinningAmount
	FROM dbo.rmBettrans b WITH (NOLOCK)
	WHERE TransDate > @LastTransDate
		AND matchid = 38
		AND statusID = 0
		AND ((@IsTest = 0 AND currency <> 20) 
			OR (@IsTest = 1 AND currency = 20)
			)
		AND ((hdp2 IN (2,3) AND odds2 > 40)
			OR (hdp2 IN (4,5) AND odds2 > 80)
			OR (hdp2 >= 6 AND odds2 > 100)
			)
		AND NOT EXISTS (SELECT 1 FROM dbo.rmLastTicketAlert t WITH (NOLOCK) WHERE b.transid = t.transid AND t.JobType = 6)

	CREATE CLUSTERED INDEX CIX_Refno ON #tmpBettrans(Refno)

	DECLARE @MBBU TABLE (BalanceUpDay SMALLDATETIME, MoveBetsDay SMALLDATETIME)
	INSERT INTO @MBBU (BalanceUpDay, MoveBetsDay)
	EXEC bodb02.dbo.Age_SelBalanceUpDay

	DECLARE @BalanceUpDay SMALLDATETIME, @MoveBetsDay SMALLDATETIME
	SELECT  @BalanceUpDay = BalanceUpDay, @MoveBetsDay = MoveBetsDay FROM @MBBU	

	INSERT INTO #tmpBettransm 
		(refno, 
		matchid, 
		homeid, 
		awayid, 
		sporttype, 
		leagueid)
	SELECT DISTINCT
		bm.refno,
		bm.matchid,
		m.homeid,
		m.awayid,
		m.sporttype,
		m.leagueid
	FROM bodb02.dbo.bettransm bm WITH(NOLOCK)
		INNER JOIN bodb02.dbo.match m WITH (NOLOCK) ON bm.matchid = m.matchid
		INNER JOIN #tmpBettrans b ON bm.refno = b.refno
	WHERE bm.statusID = 0
		AND (bm.winlostdate > @MoveBetsDay OR bm.winlostdate IS NULL)
		AND m.sporttype IN (1, 2) 
		AND m.eventstatus = 'running'	
	UNION
	SELECT DISTINCT
		bm.refno,
		bm.matchid,
		m.homeid,
		m.awayid,
		m.sporttype,
		m.leagueid
	FROM bodb02.dbo.bettransm14 bm WITH(NOLOCK)
		INNER JOIN bodb02.dbo.match14 m WITH (NOLOCK) ON bm.matchid = m.matchid
		INNER JOIN #tmpBettrans b ON bm.refno = b.refno
	WHERE bm.statusID = 0
		AND bm.winlostdate BETWEEN @BalanceUpDay AND @MoveBetsDay
		AND m.sporttype IN (1, 2) 
		AND m.eventstatus = 'running'	

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