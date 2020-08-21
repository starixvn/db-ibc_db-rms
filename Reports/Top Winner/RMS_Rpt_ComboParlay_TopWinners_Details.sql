/*<info serverAlias="DBRMS-bodb_RMS" executers="bodbRMSNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[RMS_Rpt_ComboParlay_TopWinners_Details]
	@custid			INT,
	@fromdate		DATETIME,
	@todate			DATETIME,
	@sporttype		VARCHAR(100) = '',
	@MoveBetsDay	DATETIME,
	@selection		VARCHAR(MAX) = '',
	@ParlayType		VARCHAR(10) = ''
AS

/*
	Created: 20160511@Winnie
	DB: DBRMS-bodb_RMS
	Task: Combo Parlay bet list for top winners

	Revisions:
		- 20160921@Winnie: Fix bug wrong bettype and fix ticket bettype 29 old format and conflict refno with racing RedmineID: #64286
		- 20170719@Winnie: Add MuayThai RedmineID: #79500
		- 20180927@Jacob: Apply Extra PT and Super Comm to Report.  RedmineID: #100951 		
		- 20190214@Jacob: Add Bet Builder RedmineID: #108694
		- 20191211@Jacob: Extra PT - Add new structure to support extra pt column on bettrans table #124194
		- 20200510@Percy: Add Penalty Shootout Combo [RedmineID: #133961]
		- 20200821@Percy: Fix issue duplicate data due to MBBU process [RedmineID: #140078]
	
	Parameter's Explanation:
		- @ParlayType:
					. 1: Mix parlay
					. 2: Combo parlay
					. 3: Single Match Parlay
					. 4: Panalty shootout combo
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @MBU TABLE (BalanceUpDay SMALLDATETIME, MoveBetsDay SMALLDATETIME)
	INSERT INTO @MBU (BalanceUpDay, MoveBetsDay)
	EXEC bodb02.dbo.Age_SelBalanceUpDay

	DECLARE @BalanceUpDay SMALLDATETIME
	SELECT  @BalanceUpDay = BalanceUpDay, @MoveBetsDay = MoveBetsDay FROM @MBU

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

		-- Combo parlay
		DECLARE @ComboType TINYINT = 0 -- 1: mix parlay only, 2: combo parlay only, 3: combined
		
		IF ',' + @ParlayType + ',' LIKE '%,1,%' OR ',' + @ParlayType + ',' LIKE '%,2,%'
		BEGIN
			INSERT INTO #bettype (bettype)
			VALUES (29)

			IF (SELECT COUNT(DISTINCT val) FROM dbo.f_RMS_strSplit(@ParlayType, ',') WHERE val IN (1,2)) = 2
				SELECT @ComboType = 3
			ELSE IF ',' + @ParlayType + ',' LIKE '%,1,%'
				SELECT @ComboType = 1
			ELSE
				SELECT @ComboType = 2
		END

		-- Single match parlay
		IF ',' + @ParlayType + ',' LIKE '%,3,%'
			INSERT INTO #bettype (bettype)
			VALUES (38)

		-- Penalty shootout combo
		IF ',' + @ParlayType + ',' LIKE '%,4,%'
			INSERT INTO #bettype (bettype)
			VALUES (376)

		DECLARE @f_date SMALLDATETIME, @t_date SMALLDATETIME

		CREATE TABLE #tmpBettrans
		(
			transid					BIGINT PRIMARY KEY NONCLUSTERED
			,refno					BIGINT
			,sporttype				SMALLINT
			,bettype				INT
			,betteam				NVARCHAR(10)
			,combo					TINYINT			
			,TotalCombo				BIGINT
			,ParlayType				TINYINT
			,stake					MONEY
			,winlost				MONEY
			,company_winlost		MONEY
			,stake_baseRM			MONEY
			,winlost_baseRM			MONEY
			,company_winlost_baseRM	MONEY
		)

		-- rmBettrans
		IF @ToDate > @MoveBetsDay
		BEGIN
			SELECT	@f_date = CASE WHEN @FromDate <= @MoveBetsDay THEN DATEADD(DAY, 1, @MoveBetsDay) ELSE @FromDate END
					,@t_date = @ToDate

			INSERT INTO #tmpBettrans
			(
				transid, refno, sporttype, bettype, combo, TotalCombo, ParlayType, stake, winlost, company_winlost, stake_baseRM, winlost_baseRM, company_winlost_baseRM
			)
			SELECT transid, refno, transid2, b.bettype, hdp2 AS combo, TotalBet AS TotalCombo
				,CASE
					WHEN b.bettype = 29 AND betteam = N'1' THEN 1
					WHEN b.bettype = 29 AND betteam <> N'1' THEN 2
					WHEN b.bettype = 38 THEN 3
					WHEN b.bettype = 376 THEN 4
					ELSE 0 END AS ParlayType
				,stake
				,winlost - actual_stake
				,-(winlost - actual_stake) * (1 - tpositiontaking - CAST(ISNULL(epositiontaking, 0) AS DECIMAL(9,8))) - scomm  + scomm * CAST(ISNULL(epositiontaking, 0) AS DECIMAL(9,8)) / (1 - tpositiontaking)
				,stake * actualrate
				,(winlost - actual_stake) * actualrate
				,(-(winlost - actual_stake) * (1 - tpositiontaking - CAST(ISNULL(epositiontaking, 0) AS DECIMAL(9,8))) - scomm  + scomm * CAST(ISNULL(epositiontaking, 0) AS DECIMAL(9,8)) / (1 - tpositiontaking)) * actualrate
			FROM dbo.rmBettrans b WITH (NOLOCK)
				INNER JOIN #bettype bt ON b.bettype = bt.bettype
				INNER JOIN #tmpSelection s ON b.hdp2 = s.selection
				INNER JOIN #tmpSport sp ON b.transid2 = sp.sporttype
			WHERE winlostdate BETWEEN @f_date AND @t_date
				AND custid = @custid
				AND statusID IN (112, 113)
				AND 1 = CASE
							WHEN b.bettype = 29 AND @ComboType IN (1, 2) THEN CASE
								WHEN @ComboType = 1 AND b.betteam = N'1' THEN 1
								WHEN @ComboType = 2 AND b.betteam <> N'1' THEN 1
								ELSE 0 END
							ELSE 1 END
		END

		-- bettrans14
		IF @FromDate <= @MoveBetsDay
		BEGIN
			SELECT	@f_date = @FromDate
					,@t_date = CASE WHEN @ToDate > @MoveBetsDay THEN @MoveBetsDay ELSE @ToDate END

			INSERT INTO #tmpBettrans
			(
				transid, refno, sporttype, bettype, betteam, combo, TotalCombo, ParlayType, stake, winlost, company_winlost, stake_baseRM, winlost_baseRM, company_winlost_baseRM
			)
			SELECT transid, refno, CASE WHEN b.bettype IN (38, 376) THEN 1 ELSE 0 END AS sporttype, b.bettype, betteam, hdp2, CASE WHEN b.bettype IN (38, 376) THEN 1 ELSE 0 END AS TotalCombo
				,CASE
					WHEN b.bettype = 29 AND betteam = N'1' THEN 1
					WHEN b.bettype = 29 AND betteam <> N'1' THEN 2
					WHEN b.bettype = 38 THEN 3
					WHEN b.bettype = 376 THEN 4
					ELSE 0 END AS ParlayType
				,stake
				,winlost-actual_stake
				,-(winlost - actual_stake) * (1 - tpositiontaking - CAST(ISNULL(epositiontaking, 0) AS DECIMAL(9,8))) - scomm  + scomm * CAST(ISNULL(epositiontaking, 0) AS DECIMAL(9,8)) / (1 - tpositiontaking)
				,stake * actualrate
				,(winlost - actual_stake) * actualrate
				,(-(winlost - actual_stake) * (1 - tpositiontaking - CAST(ISNULL(epositiontaking, 0) AS DECIMAL(9,8))) - scomm  + scomm * CAST(ISNULL(epositiontaking, 0) AS DECIMAL(9,8)) / (1 - tpositiontaking) ) * actualrate
			FROM bodb02.dbo.bettrans14 b WITH (NOLOCK)
				INNER JOIN #bettype bt ON b.bettype = bt.bettype
			WHERE winlostdate BETWEEN @f_date AND @t_date
				AND custid = @custid
				AND statusID IN (112, 113)
				AND 1 = CASE
							WHEN b.bettype = 29 AND @ComboType IN (1, 2) THEN CASE
								WHEN @ComboType = 1 AND b.betteam = N'1' THEN 1
								WHEN @ComboType = 2 AND b.betteam <> N'1' THEN 1
								ELSE 0 END
							ELSE 1 END

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
				CREATE TABLE #tmpBettransm (refno BIGINT, sporttype INT)
				CREATE CLUSTERED INDEX IX_refno ON #tmpBettransm (refno)

				INSERT INTO #tmpbettransm (refno, sporttype)
				SELECT bm.refno, m.sporttype
				FROM #tmpBettrans b
					INNER JOIN bodb02.dbo.bettransm bm WITH (NOLOCK) ON bm.refno = b.refno
					INNER JOIN bodb02.dbo.match m (NOLOCK) ON bm.matchid = m.matchid
				WHERE b.bettype = 29 AND b.sporttype = 0 AND bm.winlostdate > @MoveBetsDay
		
				INSERT INTO #tmpbettransm (refno, sporttype)
				SELECT bm.refno, m.sporttype
				FROM #tmpBettrans b
					INNER JOIN bodb02.dbo.bettransm14 bm WITH (NOLOCK) ON bm.refno = b.refno
					INNER JOIN bodb02.dbo.match14 m (NOLOCK) ON bm.matchid = m.matchid
				WHERE b.bettype = 29 AND b.sporttype = 0 AND bm.winlostdate BETWEEN @BalanceUpDay AND @MoveBetsDay

				INSERT INTO #tmpbettransm (refno, sporttype)
				SELECT bm.refno, m.sporttype
				FROM #tmpBettrans b
					INNER JOIN DBARC.bodb_Archive.dbo.bettransm bm WITH (NOLOCK) ON bm.refno = b.refno
					INNER JOIN DBARC.bodb_Archive.dbo.match_bk m (NOLOCK) ON bm.matchid = m.matchid
				WHERE b.bettype = 29 AND b.sporttype = 0 AND bm.winlostdate < @BalanceUpDay
		
				UPDATE b
				SET b.sporttype = s.sporttype
				FROM #tmpBettrans b
					CROSS APPLY (
						SELECT CASE
									WHEN COUNT(DISTINCT sporttype) = 1 THEN MIN(sporttype)
									WHEN COUNT(DISTINCT sporttype) <> 1 AND MIN(sporttype) = 1 THEN -3
									ELSE -1 END AS sporttype
						FROM #tmpBettransm bm
						WHERE b.refno = bm.refno
					) s
				WHERE b.bettype = 29 AND b.sporttype = 0

				DROP TABLE #tmpBettransm
			END
		END
	END

	-- Return data
	SELECT
		b.transid
		,b.refno
		,b.sporttype
		,b.bettype
		,b.combo
		,b.TotalCombo
		,b.ParlayType
		,b.stake
		,b.winlost
		,b.company_winlost
		,b.stake_baseRM
		,b.winlost_baseRM
		,b.company_winlost_baseRM
	FROM #tmpBettrans b
		INNER JOIN #tmpSelection s ON b.combo = s.selection
		INNER JOIN #tmpSport sp ON b.sporttype = sp.sporttype
	ORDER BY transid DESC

	DROP TABLE #bettype
	DROP TABLE #tmpBettrans
	DROP TABLE #tmpSelection
	DROP TABLE #tmpSport
END
GO