/*<info serverAlias="DBRMS-bodb_RMS" executers="bodbRMSNet" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[RMS_ManageAlert_AlertDetail]
	@AlertID BIGINT,
	@Selection VARCHAR(MAX) = '0',
	@Odds SMALLMONEY = NULL,
	@TicketStatus VARCHAR(50) = '-1'

AS
/*
	Created by: 20230620@Cherry.Dang
	Task : Manage Alert Letstalk on PRMS
	DB: DBRMS/bodb_RMS
	
	Revisions:		
		20230620@Cherry: Initial (#189147)
		20230830@Cherry: Enhance (#192682)
		20231101@Cherry: Parlay Generator (#195498)
		20240102@Cherry: Parlay Type for Parlay Boost (#199217)
		20240115@Cherry: Change attribute for Parlay Generator (#199766)

	Param:
		@TicketStatus = 112: Won
					  = 113: Lose
					  = 0: Running
					  = -1: All
		
*/

BEGIN
	SET NOCOUNT ON

	CREATE TABLE #tmpSelection (Selection INT)
	CREATE TABLE #tmpStatusID(StatusID TINYINT)

	IF ',' + @Selection + ',' LIKE '%,0,%'
	BEGIN
		SELECT @Selection = '2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,64,65,66,67,68,69,70,71,72,73,74,75,76,77,78,79,80,81,82,83,84,85,86,87,88,89,90,91,92,93,94,95,96,97,98,99,100'
		
		INSERT INTO #tmpSelection (selection)
		SELECT value FROM STRING_SPLIT(@Selection, ',')
	END
	ELSE IF ',' + @Selection + ',' LIKE '%,10,%'
	BEGIN
		SELECT @Selection = @Selection + ',11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,64,65,66,67,68,69,70,71,72,73,74,75,76,77,78,79,80,81,82,83,84,85,86,87,88,89,90,91,92,93,94,95,96,97,98,99,100'
		
		INSERT INTO #tmpSelection (Selection)
		SELECT value FROM STRING_SPLIT(@Selection, ',')
	END
	ELSE
	BEGIN
		INSERT INTO #tmpSelection (Selection)
		SELECT value FROM STRING_SPLIT(@Selection, ',')
	END

	IF @TicketStatus <> '-1' 
	BEGIN
		INSERT INTO #tmpStatusID (StatusID)
		SELECT val
        FROM bodb02.dbo.strSplit(@TicketStatus, ',')
	END

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
		UserName NVARCHAR(50),
		Odds MONEY,		
		Stake MONEY,
		WinningAmt MONEY,
		HouseAmt MONEY,
		Ip VARCHAR(50),
		HousePT SMALLMONEY,
		TotalBet INT,
		TotalSelection SMALLMONEY,
		Sporttype BIGINT,
		Status NVARCHAR(10),
		IsParlayGenerator BIT,
		IsBoostBonus BIT
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
			(p.stake * CASE WHEN p.currency = 20 THEN 1 ELSE p.actualrate END) AS stake,
			CASE WHEN p.statusID = 0 THEN p.stake * (p.odds2 - 1) * CASE WHEN p.currency = 20 THEN 1 ELSE p.actualrate END
				 WHEN p.statusID = 112 THEN (p.winlost - p.actual_stake) * CASE WHEN p.currency = 20 THEN 1 ELSE p.actualrate END
				 ELSE 0
			END AS WinningAmt,
			CASE WHEN p.statusID = 0 THEN p.stake * (p.odds2 - 1) * CASE WHEN p.currency = 20 THEN 1 ELSE p.actualrate END * (1 - p.tpositiontaking)
				 WHEN p.statusID IN (112,113) THEN -(((winlost - actual_stake) * (1 - p.tpositiontaking - CONVERT(DECIMAL(9, 8), ISNULL(p.epositiontaking, 0))) + scomm - CASE WHEN tpositiontaking = 1 THEN 0 ELSE scomm * CONVERT(DECIMAL(9, 8), ISNULL(p.epositiontaking, 0)) / (1 - tpositiontaking) END) * CASE WHEN p.currency = 20 THEN 1 ELSE p.actualrate END)
					 ELSE 0
			END AS HouseAmt,
			p.status
		FROM dbo.rmBettrans p WITH (NOLOCK) 
			LEFT JOIN bodb02.dbo.CustInfo ci WITH(NOLOCK) ON p.custid = ci.custid
			LEFT JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON p.custid = c.custid
			LEFT JOIN bodb02.dbo.site s WITH(NOLOCK) ON c.site = s.site
		WHERE transid IN (SELECT TransID FROM #tmpTransID)
			AND (@TicketStatus = '-1'
				OR EXISTS(SELECT TOP 1 1 FROM #tmpStatusID t WHERE p.StatusID = t.StatusID))

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
			(p.stake * CASE WHEN p.currency = 20 THEN 1 ELSE p.actualrate END) AS stake,
			CASE WHEN p.statusID = 0 THEN p.stake * (p.odds2 - 1) * CASE WHEN p.currency = 20 THEN 1 ELSE p.actualrate END
				 WHEN p.statusID = 112 THEN (p.winlost - p.actual_stake) * CASE WHEN p.currency = 20 THEN 1 ELSE p.actualrate END
				 ELSE 0
			END AS WinningAmt,
			CASE WHEN p.statusID = 0 THEN p.stake * (p.odds2 - 1) * CASE WHEN p.currency = 20 THEN 1 ELSE p.actualrate END * (1 - p.tpositiontaking)
				 WHEN p.statusID IN (112,113) THEN -(((winlost - actual_stake) * (1 - p.tpositiontaking - CONVERT(DECIMAL(9, 8), ISNULL(p.epositiontaking, 0))) + scomm - CASE WHEN tpositiontaking = 1 THEN 0 ELSE scomm * CONVERT(DECIMAL(9, 8), ISNULL(p.epositiontaking, 0)) / (1 - tpositiontaking) END) * CASE WHEN p.currency = 20 THEN 1 ELSE p.actualrate END)				
				 ELSE 0
			END AS HouseAmt,
			p.status
		FROM dbo.rmBettrans_Old p WITH (NOLOCK) 
			LEFT JOIN bodb02.dbo.CustInfo ci WITH(NOLOCK) ON p.custid = ci.custid
			LEFT JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON p.custid = c.custid
			LEFT JOIN bodb02.dbo.site s WITH(NOLOCK) ON c.site = s.site
		WHERE transid IN (SELECT TransID FROM #tmpTransID)
			AND transid NOT IN (SELECT TransID FROM #tmpSimilar)
			AND (@TicketStatus = '-1'
				OR EXISTS(SELECT TOP 1 1 FROM #tmpStatusID t WHERE p.StatusID = t.StatusID))

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
			UserName,
			Odds,			
			Stake,
			WinningAmt,
			HouseAmt,
			Ip,
			HousePT,
			TotalBet,
			TotalSelection,
			Sporttype,
			Status,
			IsParlayGenerator,
			IsBoostBonus
		)
		SELECT
			transdate,
			transid,
			RefNo,
			p.CustID,
			BetType,
			c.username,
			odds2 * TotalBet,			
			stake * CASE WHEN p.currency = 20 THEN 1 ELSE p.actualrate END AS stake,
			CASE WHEN statusID = 0 THEN stake * (odds2 - 1) * CASE WHEN p.currency = 20 THEN 1 ELSE p.actualrate END
				 WHEN statusID = 112 THEN (winlost - actual_stake) * CASE WHEN p.currency = 20 THEN 1 ELSE p.actualrate END
				 ELSE 0
			END AS WinningAmt,
			CASE WHEN statusID = 0 THEN stake * (odds2 - 1) * CASE WHEN p.currency = 20 THEN 1 ELSE p.actualrate END * (1 - tpositiontaking) 
				 WHEN statusID IN (112,113) THEN -(((winlost - actual_stake) * (1 - tpositiontaking - CONVERT(DECIMAL(9, 8), ISNULL(epositiontaking, 0))) + scomm - CASE WHEN tpositiontaking = 1 THEN 0 ELSE scomm * CONVERT(DECIMAL(9, 8), ISNULL(epositiontaking, 0)) / (1 - tpositiontaking) END) * CASE WHEN p.currency = 20 THEN 1 ELSE p.actualrate END)				 
				 ELSE 0
			END AS HouseAmt,
			ip,
			1 - tpositiontaking AS HousePT,
			TotalBet,
			hdp2 AS TotalSelection,
			transid2 AS Sporttype,
			status,
			CAST(CASE WHEN p.bettype = 29 AND p.betteam = N'1' 
					AND ISNULL(TRY_CAST(TRY_CAST(p.ExtraInfo AS XML).value('(/p1/@bac)[1]', 'VARCHAR(50)') AS INT),0)|16 = ISNULL(TRY_CAST(TRY_CAST(p.ExtraInfo AS XML).value('(/p1/@bac)[1]', 'VARCHAR(50)') AS INT),0) 
					THEN 1 ELSE 0 END AS BIT),
			CAST(CASE WHEN p.bettype = 29 AND p.betteam = N'1' AND p.oddsspread = 2 THEN 1 ELSE 0 END AS BIT)
		FROM dbo.rmBettrans p WITH (NOLOCK) 
			LEFT JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON p.custid = c.custid
		WHERE transid IN (SELECT TransID FROM #tmpTransID)
			AND p.hdp2 IN (SELECT selection FROM #tmpSelection)
			AND (@Odds IS NULL OR p.odds2 * p.TotalBet <= @Odds)
			AND (@TicketStatus = '-1'
				OR EXISTS(SELECT TOP 1 1 FROM #tmpStatusID t WHERE p.StatusID = t.StatusID))

		INSERT INTO #tmpPotential
		(
			TransDate,
			TransID,
			RefNo,
			CustID,
			BetType,
			UserName,
			Odds,			
			Stake,
			WinningAmt,
			HouseAmt,
			Ip,
			HousePT,
			TotalBet,
			TotalSelection,
			Sporttype,
			Status,
			IsParlayGenerator,
			IsBoostBonus
		)
		SELECT
			transdate,
			transid,
			RefNo,
			p.CustID,
			BetType,
			c.username,
			odds2 * TotalBet,			
			stake * CASE WHEN p.currency = 20 THEN 1 ELSE p.actualrate END AS stake,
			CASE WHEN statusID = 0 THEN stake * (odds2 - 1) * CASE WHEN p.currency = 20 THEN 1 ELSE p.actualrate END
				 WHEN statusID = 112 THEN (winlost - actual_stake) * CASE WHEN p.currency = 20 THEN 1 ELSE p.actualrate END
				 ELSE 0
			END AS WinningAmt,
			CASE WHEN statusID = 0 THEN stake * (odds2 - 1) * CASE WHEN p.currency = 20 THEN 1 ELSE p.actualrate END * (1 - tpositiontaking) 
				 WHEN statusID IN (112,113) THEN -(((winlost - actual_stake) * (1 - tpositiontaking - CONVERT(DECIMAL(9, 8), ISNULL(epositiontaking, 0))) + scomm - CASE WHEN tpositiontaking = 1 THEN 0 ELSE scomm * CONVERT(DECIMAL(9, 8), ISNULL(epositiontaking, 0)) / (1 - tpositiontaking) END) * CASE WHEN p.currency = 20 THEN 1 ELSE p.actualrate END)				 
				 ELSE 0
			END AS HouseAmt,
			ip,
			1 - tpositiontaking AS HousePT,
			TotalBet,
			hdp2 AS TotalSelection,
			transid2 AS Sporttype,
			status,
			CAST(CASE WHEN p.bettype = 29 AND p.betteam = N'1' 
					AND ISNULL(TRY_CAST(TRY_CAST(p.ExtraInfo AS XML).value('(/p1/@bac)[1]', 'VARCHAR(50)') AS INT),0)|16 = ISNULL(TRY_CAST(TRY_CAST(p.ExtraInfo AS XML).value('(/p1/@bac)[1]', 'VARCHAR(50)') AS INT),0) 
					THEN 1 ELSE 0 END AS BIT),
			CAST(CASE WHEN p.bettype = 29 AND p.betteam = N'1' AND p.oddsspread = 2 THEN 1 ELSE 0 END AS BIT)
		FROM dbo.rmBettrans_Old p WITH (NOLOCK) 
			LEFT JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON p.custid = c.custid
		WHERE transid IN (SELECT TransID FROM #tmpTransID)
			AND transid NOT IN (SELECT TransID FROM #tmpPotential)
			AND p.hdp2 IN (SELECT selection FROM #tmpSelection)
			AND (@Odds IS NULL OR p.odds2 * p.TotalBet <= @Odds)
			AND (@TicketStatus = '-1'
				OR EXISTS(SELECT TOP 1 1 FROM #tmpStatusID t WHERE p.StatusID = t.StatusID))

		SELECT
			TransDate,
			TransID,
			RefNo,
			CustID,
			BetType,
			UserName,
			Odds,
			Stake,
			WinningAmt,
			HouseAmt,
			Ip,
			HousePT,
			TotalBet,
			TotalSelection,
			CASE WHEN t.Sporttype = 1  THEN 'Soccer Only'
				 WHEN t.Sporttype = -4 THEN 'Virtual Soccer Only'
				 WHEN t.Sporttype = -5 THEN 'Virtual Basketball Only'
				 WHEN t.Sporttype = -3 THEN 'Combined Sports'
				 WHEN t.Sporttype = -1 THEN 'Combined Other Sports'
				 WHEN t.Sporttype NOT IN (1, -4, -5, -3, -1) THEN s.SportName
			END  AS SportType,
			Status,
			IsParlayGenerator,
			IsBoostBonus
		FROM #tmpPotential t
			LEFT JOIN bodb02.dbo.Sports s WITH(NOLOCK) ON t.Sporttype = s.SportType
	END	
	
	DROP TABLE #tmpSimilar
	DROP TABLE #tmpTransID
	DROP TABLE #tmpPotential
	DROP TABLE #tmpSelection
	DROP TABLE #tmpStatusID

END 
 

