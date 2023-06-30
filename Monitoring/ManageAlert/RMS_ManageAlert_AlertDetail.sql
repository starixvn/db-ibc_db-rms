/*<info serverAlias="DBRMS-bodb_RMS" executers="bodbRMSNet" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[RMS_ManageAlert_AlertDetail]
	@AlertID BIGINT

AS
/*
	Created by: 20230620@Cherry.Dang
	Task : Manage Alert Letstalk on PRMS
	DB: DBRMS/bodb_RMS
	
	Revisions:		
		20230620@Cherry: Initial (#189147)

	Param:
		
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @AlertType SMALLINT
	CREATE TABLE #tmpTransID (TransID BIGINT)	

	CREATE TABLE #tmpSimilar
	(
		TransID BIGINT,
		RefNo BIGINT,
		CustID INT,
		BetType SMALLINT,
		SiteGroup VARCHAR(10),
		UserName NVARCHAR(50),
		CustomerClass SMALLINT,
		Stake MONEY,
		WinningAmt MONEY,
		HouseAmt MONEY,
		Status NVARCHAR(10)
	)

	CREATE TABLE #tmpPotential
	(
		TransDate DATETIME,
		TransID BIGINT,
		RefNo BIGINT,
		CustID INT,
		BetType SMALLINT,
		Odds SMALLMONEY,
		Stake MONEY,
		WinningAmt MONEY,
		HouseAmt MONEY,
		Ip VARCHAR(50),
		HousePT SMALLMONEY,
		TotalBet INT,
		TotalSelection SMALLMONEY,
		Sporttype BIGINT,
		Status NVARCHAR(10)
	)
	
	SELECT @AlertType = AlertType
	FROM dbo.rmAlert WITH(NOLOCK)
	WHERE AlertID = @AlertID

	INSERT INTO #tmpTransID(TransID)
	SELECT RefValInt 
	FROM dbo.rmAlertDetail WITH(NOLOCK)
	WHERE AlertID = @AlertID
		AND RefType = 1

	IF @AlertType = 1 --Similar Bet
	BEGIN
		INSERT INTO #tmpSimilar
		(
			TransID,
			RefNo,
			CustID,
			BetType,
			SiteGroup,
			UserName,
			CustomerClass,
			Stake,
			WinningAmt,
			HouseAmt,
			Status
		)
		SELECT
			p.transid,
			p.RefNo,
			p.CustID,
			p.BetType,
			CASE WHEN s.isDeposit = 0 OR s.site = 'Saba789' THEN 'C' ELSE 'L' END SiteGroup,
			p.username,
			ci.CustomerClass,
			(p.stake * p.actualrate) AS stake,
			CASE WHEN p.statusID = 0 THEN p.stake * (p.odds2 - 1) * p.actualrate * (1 - p.tpositiontaking)
				 WHEN p.statusID = 112 THEN (p.winlost - p.actual_stake) * p.actualrate
				 ELSE 0
			END AS WinningAmt,
			CASE WHEN p.statusID = 0 THEN (p.odds2 - 1) * p.stake * p.actualrate 
				 WHEN p.statusID IN (112, 113) THEN ((winlost - actual_stake) * (1 - p.tpositiontaking - CONVERT(DECIMAL(9, 8), ISNULL(p.epositiontaking, 0))) + scomm - CASE WHEN tpositiontaking = 1 THEN 0 ELSE scomm * CONVERT(DECIMAL(9, 8), ISNULL(p.epositiontaking, 0)) / (1 - tpositiontaking) END) * actualrate
				 ELSE 0
			END AS HouseAmt,
			p.status
		FROM dbo.rmBettrans p WITH (NOLOCK) 
			INNER JOIN bodb02.dbo.CustInfo ci WITH(NOLOCK) ON p.custid = ci.custid
			LEFT JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON p.custid = c.custid
			LEFT JOIN bodb02.dbo.site s WITH(NOLOCK) ON c.site = s.site
		WHERE transid IN (SELECT TransID FROM #tmpTransID)

		INSERT INTO #tmpSimilar
		(
			TransID,
			RefNo,
			CustID,
			BetType,
			SiteGroup,
			UserName,
			CustomerClass,
			Stake,
			WinningAmt,
			HouseAmt,
			Status
		)
		SELECT
			p.transid,
			p.RefNo,
			p.CustID,
			p.BetType,
			CASE WHEN s.isDeposit = 0 OR s.site = 'Saba789' THEN 'C' ELSE 'L' END SiteGroup,
			p.username,
			ci.CustomerClass,
			(p.stake * p.actualrate) AS stake,
			CASE WHEN p.statusID = 0 THEN p.stake * (p.odds2 - 1) * p.actualrate * (1 - p.tpositiontaking)
				 WHEN p.statusID = 112 THEN (p.winlost - p.actual_stake) * p.actualrate
				 ELSE 0
			END AS WinningAmt,
			CASE WHEN p.statusID = 0 THEN (p.odds2 - 1) * p.stake * p.actualrate 
				 WHEN p.statusID IN (112, 113) THEN ((winlost - actual_stake) * (1 - p.tpositiontaking - CONVERT(DECIMAL(9, 8), ISNULL(p.epositiontaking, 0))) + scomm - CASE WHEN tpositiontaking = 1 THEN 0 ELSE scomm * CONVERT(DECIMAL(9, 8), ISNULL(p.epositiontaking, 0)) / (1 - tpositiontaking) END) * actualrate
				 ELSE 0
			END AS HouseAmt,
			p.status
		FROM dbo.rmBettrans_Old p WITH (NOLOCK) 
			INNER JOIN bodb02.dbo.CustInfo ci WITH(NOLOCK) ON p.custid = ci.custid
			LEFT JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON p.custid = c.custid
			LEFT JOIN bodb02.dbo.site s WITH(NOLOCK) ON c.site = s.site
		WHERE transid IN (SELECT TransID FROM #tmpTransID)
			AND transid NOT IN (SELECT TransID FROM #tmpSimilar)

		SELECT
			TransID,
			RefNo,
			CustID,
			BetType,
			SiteGroup,
			UserName,
			CustomerClass,
			Stake,
			WinningAmt,
			HouseAmt,
			Status
		FROM #tmpSimilar
	END

	IF @AlertType = 3 --Potential Winning
	BEGIN
		INSERT INTO #tmpPotential
		(
			TransDate,
			TransID,
			RefNo,
			CustID,
			BetType,
			Odds,
			Stake,
			WinningAmt,
			HouseAmt,
			Ip,
			HousePT,
			TotalBet,
			TotalSelection,
			Sporttype,
			Status
		)
		SELECT
			transdate,
			transid,
			RefNo,
			CustID,
			BetType,
			odds2 * TotalBet,
			stake * actualrate AS stake,
			CASE WHEN statusID = 0 THEN stake * (odds2 - 1) * actualrate * (1 - tpositiontaking)
				 WHEN statusID = 112 THEN (winlost - actual_stake) * actualrate
				 ELSE 0
			END AS WinningAmt,
			CASE WHEN statusID = 0 THEN (odds2 - 1) * stake * actualrate 
				 WHEN statusID IN (112, 113) THEN ((winlost - actual_stake) * (1 - tpositiontaking - CONVERT(DECIMAL(9, 8), ISNULL(epositiontaking, 0))) + scomm - CASE WHEN tpositiontaking = 1 THEN 0 ELSE scomm * CONVERT(DECIMAL(9, 8), ISNULL(epositiontaking, 0)) / (1 - tpositiontaking) END) * actualrate
				 ELSE 0
			END AS HouseAmt,
			ip,
			1 - tpositiontaking AS HousePT,
			TotalBet,
			hdp2 AS TotalSelection,
			CASE WHEN transid2 NOT IN (-1,-3,1,2,3,4,5,6,7,8,9,11,43,44,-4,-5) THEN -2 ELSE transid2 END AS Sporttype,
			status
		FROM dbo.rmBettrans WITH (NOLOCK) 
		WHERE transid IN (SELECT TransID FROM #tmpTransID)

		INSERT INTO #tmpPotential
		(
			TransDate,
			TransID,
			RefNo,
			CustID,
			BetType,
			Odds,
			Stake,
			WinningAmt,
			HouseAmt,
			Ip,
			HousePT,
			TotalBet,
			TotalSelection,
			Sporttype,
			Status
		)
		SELECT
			transdate,
			transid,
			RefNo,
			CustID,
			BetType,
			odds2 * TotalBet,
			stake * actualrate AS stake,
			CASE WHEN statusID = 0 THEN stake * (odds2 - 1) * actualrate * (1 - tpositiontaking)
				 WHEN statusID = 112 THEN (winlost - actual_stake) * actualrate
				 ELSE 0
			END AS WinningAmt,
			CASE WHEN statusID = 0 THEN (odds2 - 1) * stake * actualrate 
				 WHEN statusID IN (112, 113) THEN ((winlost - actual_stake) * (1 - tpositiontaking - CONVERT(DECIMAL(9, 8), ISNULL(epositiontaking, 0))) + scomm - CASE WHEN tpositiontaking = 1 THEN 0 ELSE scomm * CONVERT(DECIMAL(9, 8), ISNULL(epositiontaking, 0)) / (1 - tpositiontaking) END) * actualrate
				 ELSE 0
			END AS HouseAmt,
			ip,
			1 - tpositiontaking AS HousePT,
			TotalBet,
			hdp2 AS TotalSelection,
			CASE WHEN transid2 NOT IN (-1,-3,1,2,3,4,5,6,7,8,9,11,43,44,-4,-5) THEN -2 ELSE transid2 END AS Sporttype,
			status
		FROM dbo.rmBettrans_Old WITH (NOLOCK) 
		WHERE transid IN (SELECT TransID FROM #tmpTransID)
			AND transid NOT IN (SELECT TransID FROM #tmpPotential)

		SELECT
			TransDate,
			TransID,
			RefNo,
			CustID,
			BetType,
			Odds,
			Stake,
			WinningAmt,
			HouseAmt,
			Ip,
			HousePT,
			TotalBet,
			TotalSelection,
			CASE WHEN Sporttype = 1 THEN 'Soccer Only'
				 WHEN Sporttype = -1 THEN 'Combined Other Sports'
				 WHEN Sporttype = -2 THEN 'Other Sports'
				 WHEN Sporttype = -3 THEN 'Combined Sports'
				 WHEN Sporttype = -4 THEN 'Saba Soccer'
				 WHEN Sporttype = -5 THEN 'Saba Basketball'
			END AS SportType,
			Status
		FROM #tmpPotential
	END	
	
	DROP TABLE #tmpSimilar
	DROP TABLE #tmpTransID
	DROP TABLE #tmpPotential
END 
 

