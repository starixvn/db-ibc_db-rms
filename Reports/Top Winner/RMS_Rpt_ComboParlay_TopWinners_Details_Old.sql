/*<info serverAlias="DBARC-bodb_Archive" executers="bodbRMSNet" isFunction="0" isNested="0"></info>*/
 ALTER PROCEDURE [dbo].[RMS_Rpt_ComboParlay_TopWinners_Details_Old]
	@custid			INT,
	@fromdate		DATETIME,
	@todate			DATETIME,
	@sporttype		VARCHAR(100) = '',
	@selection		VARCHAR(MAX) = '',
	@ParlayType		VARCHAR(10) = '',
	@currency		VARCHAR(MAX) = ''
AS

/*
	Created: 20160511@Winnie
	DB: DBARC-bodb_Archive
	Task: get combo parlay betlist for top winners before balanceup date
	
	Revisions:			
		- 20160921@Winnie: Fix bug wrong bettype and fix ticket bettype 29 old format RedmineID: #64286
		- 20170719@Winnie: Add MuayThai RedmineID: #79500
		- 20180927@Jacob: Apply Extra PT and Super Comm to Report.  RedmineID: #100951 		
		- 20190214@Jacob: Add Bet Builder RedmineID: #108694
		- 20191211@Jacob: Extra PT - Add new structure to support extra pt column on bettrans table #124194
		- 20200510@Percy: Add Penalty Shootout Combo [RedmineID: #133961]
		- 20200821@Percy: Fix issue duplicate data due to MBBU process [RedmineID: #140078]
		- 20201204@Danny: Separate Data of Virtual Soccer & Virtual Basketball  [RedmineID: #145926]
		- 20210218@Danny: Monitor Performance of GOF  [RedmineID: #149966]
		- 20210303@Danny: Change on Report Top Winners [RedmineID: #146554]
		- 20231020@Cherry: Parlay Generator (#195498)
		- 20231201@Cherry: Parlay Type for Parlay Boost (#197680)
	
	Parameter's Explanation:
		- @ParlayType:
					. 1: Mix parlay
					. 2: Combo parlay
					. 3: Single Match Parlay
					. 4: Panalty shootout combo
					. 5: GOF
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @MBU TABLE (BalanceUpDay SMALLDATETIME, MoveBetsDay SMALLDATETIME)
	INSERT INTO @MBU (BalanceUpDay, MoveBetsDay)
	EXEC bodb02.dbo.Age_SelBalanceUpDay

	DECLARE @BalanceUpDay SMALLDATETIME, @MoveBetsDay SMALLDATETIME
	SELECT  @BalanceUpDay = BalanceUpDay, @MoveBetsDay = MoveBetsDay FROM @MBU

	-- currency
	BEGIN
		CREATE TABLE #tmpCurrency (currency TINYINT)
		INSERT INTO #tmpCurrency (currency)
		SELECT val FROM dbo.f_RMS_strSplit(@currency, ',')

	END

	-- selections
	BEGIN
		CREATE TABLE #tmpSelection (selection INT)

		-- all selections (2 --> 100)
		IF ',' + @selection + ',' LIKE '%,0,%'
		BEGIN
			SELECT @selection = '2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,64,65,66,67,68,69,70,71,72,73,74,75,76,77,78,79,80,81,82,83,84,85,86,87,88,89,90,91,92,93,94,95,96,97,98,99,100'
		
			INSERT INTO #tmpSelection (selection)
			SELECT val FROM dbo.f_RMS_strSplit(@selection, ',')
		END
		-- 10UP (add 11 --> 100)
		ELSE IF ',' + @selection + ',' LIKE '%,10,%'
		BEGIN
			SELECT @selection = @selection + ',11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,64,65,66,67,68,69,70,71,72,73,74,75,76,77,78,79,80,81,82,83,84,85,86,87,88,89,90,91,92,93,94,95,96,97,98,99,100'
		
			INSERT INTO #tmpSelection (selection)
			SELECT val FROM dbo.f_RMS_strSplit(@selection, ',')
		END
		ELSE
		BEGIN
			INSERT INTO #tmpSelection (selection)
			SELECT val FROM dbo.f_RMS_strSplit(@selection, ',')
		END
	END

	-- sports
	BEGIN
		CREATE TABLE #tmpSport (sporttype INT)
		INSERT INTO #tmpSport (sporttype)
		SELECT val FROM dbo.f_RMS_strSplit(@sporttype, ',')

		IF ',' + @sporttype + ',' LIKE '%,-2,%'
			INSERT INTO #tmpSport (sporttype)
			SELECT SportType FROM bodb02.dbo.Sports WITH (NOLOCK)
			WHERE SportType NOT IN (1,2,3,4,5,6,7,8,9,11,43,44)
				AND SportType <= 99
	END

	-- get data
	BEGIN
		CREATE TABLE #bettype (bettype SMALLINT)

		CREATE TABLE #ParlayType (ParlayType SMALLINT)

		INSERT INTO #ParlayType (ParlayType)
			SELECT	value
			FROM STRING_SPLIT(@ParlayType, ',') 

		IF EXISTS(SELECT TOP 1 1 FROM #ParlayType WHERE ParlayType = 1) 
		BEGIN
			IF NOT EXISTS(SELECT TOP 1 1 FROM #ParlayType WHERE ParlayType = 6)
				INSERT INTO #ParlayType (ParlayType) VALUES (6)
			IF NOT EXISTS(SELECT TOP 1 1 FROM #ParlayType WHERE ParlayType = 7)
				INSERT INTO #ParlayType (ParlayType) VALUES (7)
		END

		IF EXISTS(SELECT TOP 1 1 FROM #ParlayType WHERE ParlayType IN (6,7)) 
			INSERT INTO #ParlayType (ParlayType) VALUES (77) --Parlay Generator & Boost
	
		IF ',' + @ParlayType + ',' LIKE '%,1,%' OR ',' + @ParlayType + ',' LIKE '%,2,%' OR ',' + @ParlayType + ',' LIKE '%,5,%' OR ',' + @ParlayType + ',' LIKE '%,6,%'
		BEGIN
			INSERT INTO #bettype (bettype)
			VALUES (29)			
		END

		-- Single match parlay
		IF ',' + @ParlayType + ',' LIKE '%,3,%'
			INSERT INTO #bettype (bettype)
			VALUES (38)

		-- Penalty shootout combo
		IF ',' + @ParlayType + ',' LIKE '%,4,%'
			INSERT INTO #bettype (bettype)
			VALUES (376)

		DECLARE @ExtraPTCutOffDate SMALLDATETIME
		SELECT  @ExtraPTCutOffDate = bodb02.dbo.f_Get_SystemSettings('CutOffDate_ExtraPT')

		DECLARE @SuperID INT
		SELECT  @SuperID = srecommend FROM bodb02.dbo.Customer WITH (NOLOCK) WHERE custid = @custid

		CREATE TABLE #ExtraPT (SuperID INT, FromDate DATETIME, ToDate DATETIME, ExtraPT DECIMAL(9, 8))
		INSERT INTO #ExtraPT (SuperID, FromDate, ToDate, ExtraPT)
		SELECT SuperId, FromDate, ToDate, SUM(ExtraPT) AS ExtraPT
		FROM bodb02.dbo.Acc_GroupExtraPTSetting WITH (NOLOCK)
		WHERE SuperID = @SuperID AND ProductID = 1 AND Sporttype = 0 AND SubProduct = ''
			AND (
				FromDate BETWEEN @FromDate AND @ToDate
				OR ToDate BETWEEN @FromDate AND @ToDate
			)
			AND ToDate < @ExtraPTCutOffDate
		GROUP BY SuperId, FromDate, ToDate

		CREATE TABLE #tmpGenerator
		(
			transid BIGINT,
			bact INT
		)	

		CREATE TABLE #tmpBettrans
		(
			transid					BIGINT PRIMARY KEY NONCLUSTERED
			,refno					BIGINT
			,sporttype				SMALLINT
			,bettype				INT
			,betteam				NVARCHAR(10)
			,combo					TINYINT
			,ParlayType				TINYINT
			,TotalCombo				BIGINT
			,stake					MONEY
			,winlost				MONEY
			,company_winlost		MONEY
			,stake_baseRM			MONEY
			,winlost_baseRM			MONEY
			,company_winlost_baseRM MONEY
			,IsGOF					BIT
			,IsParlayGenerator		BIT
			,currency				TINYINT
		)

		INSERT INTO #tmpGenerator (transid, bact)
		SELECT transid,
			ISNULL(TRY_CAST(TRY_CAST(ExtraInfo AS XML).value('(/p1/@bact)[1]', 'VARCHAR(50)') AS INT),0)
		FROM dbo.bettrans_bk WITH (NOLOCK)
		WHERE winlostdate BETWEEN @FromDate AND @ToDate
			AND statusID IN (112, 113)
			AND custid = @custid
			AND bettype = 29 
			AND betteam = N'1'

		INSERT INTO #tmpBettrans
		(
			transid
			,refno
			,sporttype
			,bettype
			,betteam
			,combo
			,TotalCombo
			,ParlayType
			,stake
			,winlost
			,company_winlost
			,stake_baseRM
			,winlost_baseRM
			,company_winlost_baseRM
			,IsGOF
			,IsParlayGenerator
			,currency
		)		
		SELECT
			b.transid
			,refno
			,CASE WHEN bettype IN (38, 376) THEN 1 ELSE 0 END AS sporttype
			,bettype
			,betteam
			,hdp2 AS combo
			,CASE WHEN (bettype=29 AND betteam = N'1') OR bettype IN (38, 376) THEN 1 ELSE 0 END AS TotalCombo
			,CASE
				WHEN bettype = 29 AND betteam = N'1' THEN 1
				WHEN bettype = 29 AND betteam <> N'1' THEN 2
				WHEN bettype = 38 THEN 3
				WHEN bettype = 376 THEN 4
				ELSE 0 END AS ParlayType
			,stake
			,winlost - actual_stake
			,-(winlost - actual_stake) * (1 - tpositiontaking - ISNULL(e.ExtraPT, CAST(ISNULL(epositiontaking, 0) AS DECIMAL(9,8)))) - scomm  + scomm * ISNULL(e.ExtraPT, CAST(ISNULL(epositiontaking, 0) AS DECIMAL(9,8))) / (1 - tpositiontaking) 
			,stake * actualrate
			,(winlost - actual_stake) * actualrate
			,(-(winlost - actual_stake) * (1 - tpositiontaking - ISNULL(e.ExtraPT, CAST(ISNULL(epositiontaking, 0) AS DECIMAL(9,8)))) - scomm  + scomm * ISNULL(e.ExtraPT, CAST(ISNULL(epositiontaking, 0) AS DECIMAL(9,8))) / (1 - tpositiontaking)) * actualrate	
			,CAST(CASE WHEN b.bettype = 29 AND b.betteam= N'1' AND b.oddsspread = 1 THEN 1 ELSE 0 END AS BIT) AS IsGOF
			,CAST(CASE WHEN b.bettype = 29 AND b.betteam= N'1' AND t.bact = 5 THEN 1 ELSE 0 END AS BIT) AS IsParlayGenerator
			,b.currency
		FROM dbo.bettrans_bk b WITH (NOLOCK)
			LEFT JOIN #ExtraPT e ON b.srecommend = e.SuperId AND b.winlostdate BETWEEN e.FromDate AND e.Todate
			LEFT JOIN #tmpGenerator t ON b.transid = t.transid
		WHERE winlostdate BETWEEN @FromDate AND @ToDate
			AND statusID IN (112, 113)
			AND custid = @custid
			AND EXISTS (SELECT 1 FROM #bettype bt WHERE b.bettype = bt.bettype)
			AND (b.bettype <> 29
				OR (EXISTS(SELECT TOP 1 1 FROM #ParlayType WHERE ParlayType = 1)
					AND b.bettype = 29 AND b.betteam = N'1')
				OR (EXISTS(SELECT TOP 1 1 FROM #ParlayType WHERE ParlayType = 2)
					AND b.bettype = 29 AND b.betteam <> N'1')
				OR (EXISTS(SELECT TOP 1 1 FROM #ParlayType WHERE ParlayType = 5)
					AND b.bettype = 29 AND b.betteam = N'1' AND b.oddsspread = 1)
				OR (EXISTS(SELECT TOP 1 1 FROM #ParlayType WHERE ParlayType = 6)
					AND b.bettype = 29 AND b.betteam = N'1' AND t.bact = 5)
				OR (EXISTS(SELECT TOP 1 1 FROM #ParlayType WHERE ParlayType = 7)
						AND b.bettype = 29 AND b.betteam = N'1' AND b.oddsspread = 2)
				)		

		IF EXISTS (SELECT 1 FROM #tmpBettrans WHERE bettype = 29 AND sporttype = 0)
		BEGIN
			CREATE CLUSTERED INDEX IX_bettype ON #tmpBettrans (bettype, sporttype)

			-- Update Total Combo
			UPDATE b
			SET b.TotalCombo = pt.TotalCombo
			FROM #tmpBettrans b
				CROSS APPLY (
					SELECT SUM (rcs.cnt) AS TotalCombo
					FROM bodb02.dbo.RefCombinationSet rcs WITH (NOLOCK)
					WHERE b.combo = rcs.N
						AND (b.betteam & rcs.bitmapR) > 0
				) pt
			WHERE b.bettype = 29 AND b.sporttype = 0
		
			-- Update sporttype
			CREATE TABLE #tmpBettransm (refno BIGINT, sporttype INT, Saba INT)
			CREATE CLUSTERED INDEX IX_refno ON #tmpBettransm (refno)

			INSERT INTO #tmpbettransm (refno, sporttype, Saba)
			SELECT bm.refno, m.sporttype , CASE WHEN  l.LeagueGroupID IN (42, 74) THEN 1 ELSE -1 END Saba
			FROM #tmpBettrans b
				INNER JOIN bodb02.dbo.bettransm14 bm WITH (NOLOCK) ON bm.refno = b.refno
				INNER JOIN bodb02.dbo.match14 m WITH (NOLOCK) ON bm.matchid = m.matchid
				INNER JOIN bodb02.dbo.League l WITH(NOLOCK) ON m.leagueid = l.leagueid
			WHERE b.bettype = 29 AND b.sporttype = 0 AND bm.winlostdate BETWEEN @BalanceUpDay AND @MoveBetsDay

			INSERT INTO #tmpbettransm (refno, sporttype, Saba)
			SELECT bm.refno, m.sporttype, CASE WHEN  l.LeagueGroupID IN (42, 74) THEN 1 ELSE -1 END Saba
			FROM #tmpBettrans b
				INNER JOIN DBARC.bodb_Archive.dbo.bettransm bm WITH (NOLOCK) ON bm.refno = b.refno
				INNER JOIN DBARC.bodb_Archive.dbo.match_bk m WITH (NOLOCK) ON bm.matchid = m.matchid
				INNER JOIN bodb02.dbo.League l WITH(NOLOCK) ON m.leagueid = l.leagueid
			WHERE b.bettype = 29 AND b.sporttype = 0 AND bm.winlostdate < @BalanceUpDay
		
			UPDATE b
			SET b.sporttype = s.sporttype
			FROM #tmpBettrans b
				CROSS APPLY (
					SELECT CASE
								-------------------------------
								WHEN COUNT(DISTINCT sporttype) = 1 AND MIN(sporttype) NOT IN (1,2) THEN MIN(sporttype)
								------------------------------- 
								WHEN COUNT(DISTINCT sporttype) = 1 AND MIN(sporttype) = 1 AND SUM(DISTINCT Saba) = 0 THEN -3 
								WHEN COUNT(DISTINCT sporttype) = 1 AND MIN(sporttype) = 1 AND SUM(DISTINCT Saba) > 0 THEN -4
								WHEN COUNT(DISTINCT sporttype) = 1 AND MIN(sporttype) = 1 AND SUM(DISTINCT Saba) < 0 THEN  1
								------------------------------
								WHEN COUNT(DISTINCT sporttype) = 1 AND MIN(sporttype) = 2 AND SUM(DISTINCT Saba) = 0 THEN -1
								WHEN COUNT(DISTINCT sporttype) = 1 AND MIN(sporttype) = 2 AND SUM(DISTINCT Saba) > 0 THEN -5
								WHEN COUNT(DISTINCT sporttype) = 1 AND MIN(sporttype) = 2 AND SUM(DISTINCT Saba) < 0 THEN  2

								------------------------------
								WHEN COUNT(DISTINCT sporttype) <> 1 AND MIN(sporttype) = 1 THEN -3
								ELSE -1 END AS sporttype 
					FROM #tmpBettransm bm
					WHERE b.refno = bm.refno
				) s
			WHERE b.bettype = 29 AND b.sporttype = 0

			DROP TABLE #tmpBettransm
		END
	END

	-- Return data
	SELECT
		b.transid
		,b.refno
		,b.sporttype
		,b.bettype
		,b.combo
		,b.ParlayType
		,b.TotalCombo
		,b.stake
		,b.winlost
		,b.company_winlost
		,b.stake_baseRM
		,b.winlost_baseRM
		,b.company_winlost_baseRM
		,b.IsGOF
		,b.IsParlayGenerator
	FROM #tmpBettrans b
		INNER JOIN #tmpSelection s ON b.combo = s.selection
		INNER JOIN #tmpSport sp ON b.sporttype = sp.sporttype
		INNER JOIN #tmpCurrency tc ON tc.currency = b.currency
	ORDER BY transid DESC

	DROP TABLE #bettype
	DROP TABLE #ExtraPT
	DROP TABLE #tmpBettrans
	DROP TABLE #tmpSelection
	DROP TABLE #tmpSport
	DROP TABLE #tmpCurrency
	DROP TABLE #ParlayType
	DROP TABLE #tmpGenerator
END
GO