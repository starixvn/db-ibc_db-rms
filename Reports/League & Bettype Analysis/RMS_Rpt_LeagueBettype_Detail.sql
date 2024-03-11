/*<info serverAlias="DBRMS-bodb_RMS" executers="bodbRMSNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[RMS_Rpt_LeagueBettype_Detail]
	@TransList		NVARCHAR(MAX) 
AS

/*
	Created: 20240115@Cherry
	DB: DBRMS-bodb_RMS
	Task: League & Bettype Data Analysis

	Revisions:
		- 20240115@Cherry: Initialize SP [RedmineID: #197684]

	Param's Explanation:


*/

BEGIN
	SET NOCOUNT ON

	DECLARE @MBU TABLE (BalanceUpDay SMALLDATETIME, MoveBetsDay SMALLDATETIME)
	INSERT INTO @MBU (BalanceUpDay, MoveBetsDay)
	EXEC bodb02.dbo.Age_SelBalanceUpDay

	DECLARE @MoveBetsDay DATETIME
	SELECT @MoveBetsDay = MoveBetsDay FROM @MBU		

	CREATE TABLE #tmpTransID (TransID BIGINT)

	INSERT INTO #tmpTransID (TransID)
	SELECT val
	FROM bodb02.dbo.strSplit(@TransList, ',')

	CREATE TABLE #tmpBettrans
	(
		TransDate			DATETIME,
		TransId				BIGINT,
		UserName			NVARCHAR(50),
		BetType				SMALLINT,
		Odds				SMALLMONEY,
		StakeAfterPT		MONEY,
		WinningAmount		MONEY,
		NetWinAfterPT		MONEY,
		TotalBet			INT,
		TotalSelection		INT,
		SportType			SMALLINT,
		IP					VARCHAR(45),
		CurrencyName		NVARCHAR(50),
		CustomerClass		SMALLINT
	)		
		
	INSERT INTO #tmpBettrans
	(
		transdate,
		transid,
		username,
		odds,
		StakeAfterPT,
		WinningAmount,
		NetWinAfterPT,
		TotalBet,
		TotalSelection,
		SportType,
		IP,
		currencyName,
		CustomerClass		
	)			
	SELECT
		b.transdate
		,b.transid
		,b.Username
		,(b.winlost - b.actual_stake) / b.stake AS odds
		,b.stake * (1 - b.tpositiontaking - CONVERT(DECIMAL(9, 8), ISNULL(b.epositiontaking, 0))) * b.actualrate AS StakeAfterPT
		,(b.winlost - b.actual_stake) * b.actualrate AS WinningAmount
		,((winlost - actual_stake) * (1 - b.tpositiontaking - CONVERT(DECIMAL(9, 8), ISNULL(b.epositiontaking, 0))) + scomm - CASE WHEN tpositiontaking = 1 THEN 0 ELSE scomm * CONVERT(DECIMAL(9, 8), ISNULL(b.epositiontaking, 0)) / (1 - tpositiontaking) END) * actualrate AS NetWinAfterPT
		,b.TotalBet
		,b.hdp2 AS TotalSelection
		,b.transid2 AS SportType
		,b.IP
		,b.CurrencyName
		,ci.CustomerClass
	FROM dbo.rmBettrans b WITH (NOLOCK)
		INNER JOIN bodb02.dbo.CustInfo ci WITH(NOLOCK) ON b.custid = ci.custid
	WHERE b.statusID = 112
		AND b.currency <> 20		
		AND b.transid IN (SELECT TransID FROM #tmpTransID)

	INSERT INTO #tmpBettrans
	(
		transdate,
		transid,
		username,
		odds,
		StakeAfterPT,
		WinningAmount,
		NetWinAfterPT,
		TotalBet,
		TotalSelection,
		SportType,
		IP,
		currencyName,
		CustomerClass		
	)			
	SELECT
		b.transdate
		,b.transid
		,b.Username
		,(b.winlost - b.actual_stake) / b.stake AS odds
		,b.stake * (1 - b.tpositiontaking - CONVERT(DECIMAL(9, 8), ISNULL(b.epositiontaking, 0))) * b.actualrate AS StakeAfterPT
		,(b.winlost - b.actual_stake) * b.actualrate AS WinningAmount
		,((winlost - actual_stake) * (1 - b.tpositiontaking - CONVERT(DECIMAL(9, 8), ISNULL(b.epositiontaking, 0))) + scomm - CASE WHEN tpositiontaking = 1 THEN 0 ELSE scomm * CONVERT(DECIMAL(9, 8), ISNULL(b.epositiontaking, 0)) / (1 - tpositiontaking) END) * actualrate AS NetWinAfterPT
		,b.TotalBet
		,b.hdp2 AS TotalSelection
		,b.transid2 AS SportType
		,b.IP
		,b.CurrencyName
		,ci.CustomerClass
	FROM dbo.rmBettrans_Old b WITH (NOLOCK)
		INNER JOIN bodb02.dbo.CustInfo ci WITH(NOLOCK) ON b.custid = ci.custid
	WHERE b.statusID = 112
		AND b.currency <> 20		
		AND b.transid IN (SELECT TransID FROM #tmpTransID)
		AND b.transid NOT IN (SELECT TransID FROM #tmpBettrans)

	SELECT
		TransDate,
		TransId,
		UserName,
		CustomerClass,
		CurrencyName,
		Odds,
		StakeAfterPT,
		WinningAmount,
		NetWinAfterPT,
		TotalBet,
		TotalSelection,
		SportType,
		IP
	FROM #tmpBettrans

	DROP TABLE #tmpBettrans
	DROP TABLE #tmpTransID

END
GO