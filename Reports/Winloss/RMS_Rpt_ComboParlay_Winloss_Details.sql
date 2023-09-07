/*<info serverAlias="DBRMS-bodb_RMS" executers="bodbRMSNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[RMS_Rpt_ComboParlay_Winloss_Details]
	@custid			INT,
	@fromdate		DATETIME,
	@todate			DATETIME,
	@sporttype		VARCHAR(100) = '',
	@MoveBetsDay	DATETIME,
	@selection		VARCHAR(MAX) = '',
	@ParlayType		VARCHAR(10) = '',
	@LiveStatus		TINYINT = 3
AS

/*
	Created: 20230906@Cherry
	DB: DBRMS-bodb_RMS
	Task: Get report win loss by specific member

	Revisions:
		- 20230906@Cherry: Add Bet details (#192682)
	
	Parameter's Explanation:
		- @ParlayType:
					. 1: Mix parlay
					. 2: Combo parlay
					. 3: Single Match Parlay
					. 4: Panalty shootout combo
					. 5: GOF
		
		- @sporttype:
					. -1: Combine Others sport
					. -2: Others sport
					. -3: Combine sport
					. -4: saba soccer
					. -5: saba basketball
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
			SELECT value FROM STRING_SPLIT(@selection, ',')
		END
		-- 10UP (add 11 --> 100)
		ELSE IF ',' + @selection + ',' LIKE '%,10,%'
		BEGIN
			SELECT @selection = @selection + ',11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,64,65,66,67,68,69,70,71,72,73,74,75,76,77,78,79,80,81,82,83,84,85,86,87,88,89,90,91,92,93,94,95,96,97,98,99,100'
		
			INSERT INTO #tmpSelection (selection)
			SELECT value FROM STRING_SPLIT(@selection, ',')
		END
		ELSE
		BEGIN
			INSERT INTO #tmpSelection (selection)
			SELECT value FROM STRING_SPLIT(@selection, ',')
		END
	END

	-- sports
	BEGIN
		CREATE TABLE #tmpSport (sporttype INT)
		INSERT INTO #tmpSport (sporttype)
		SELECT value FROM STRING_SPLIT(@sporttype, ',')

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
		DECLARE @ComboType TINYINT = 0	
				--1: mix parlay only, 
				--2: combo parlay only, 
				--3: GOF only, 
				--4: combined between mix parlay and GOF, 
				--5: combined between combo parlay and GOF,
				--6: combined between mix parlay and combo parlay, 
				--7: combined all
		
		IF ',' + @ParlayType + ',' LIKE '%,1,%' OR ',' + @ParlayType + ',' LIKE '%,2,%' OR ',' + @ParlayType + ',' LIKE '%,5,%'
		BEGIN
			INSERT INTO #bettype (bettype)
			VALUES (29)

			SELECT	@ComboType = CASE	WHEN COUNT(DISTINCT value) = 3 AND SUM(DISTINCT CAST(value as SMALLINT)) = 8 THEN 7 
										WHEN COUNT(DISTINCT value) = 2 AND SUM(DISTINCT CAST(value as SMALLINT)) = 3 THEN 6
										WHEN COUNT(DISTINCT value) = 2 AND SUM(DISTINCT CAST(value as SMALLINT)) = 6 THEN 4
										WHEN COUNT(DISTINCT value) = 2 AND SUM(DISTINCT CAST(value as SMALLINT)) = 7 THEN 5
										WHEN COUNT(DISTINCT value) = 1 AND SUM(DISTINCT CAST(value as SMALLINT)) = 1 THEN 1
										WHEN COUNT(DISTINCT value) = 1 AND SUM(DISTINCT CAST(value as SMALLINT)) = 2 THEN 2
										WHEN COUNT(DISTINCT value) = 1 AND SUM(DISTINCT CAST(value as SMALLINT)) = 5 THEN 3
								END
			FROM STRING_SPLIT(@ParlayType, ',') WHERE value IN (1,2,5)
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
			,IsGOF					BIT
		)

		-- rmBettrans
		IF @ToDate > @MoveBetsDay
		BEGIN
			SELECT	@f_date = CASE WHEN @FromDate <= @MoveBetsDay THEN DATEADD(DAY, 1, @MoveBetsDay) ELSE @FromDate END
					,@t_date = @ToDate

			INSERT INTO #tmpBettrans
			(
				transid, refno, sporttype, bettype, combo, TotalCombo, ParlayType, stake, winlost, company_winlost, stake_baseRM, winlost_baseRM, company_winlost_baseRM, IsGOF
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
				,CASE WHEN 1 - tpositiontaking = 0 THEN 0 ELSE -(winlost - actual_stake) * (1 - tpositiontaking - CAST(ISNULL(epositiontaking, 0) AS DECIMAL(9,8))) - scomm  + scomm * CAST(ISNULL(epositiontaking, 0) AS DECIMAL(9,8)) / (1 - tpositiontaking) END
				,stake * actualrate
				,(winlost - actual_stake) * actualrate
				,CASE WHEN 1 - tpositiontaking = 0 THEN 0 ELSE (-(winlost - actual_stake) * (1 - tpositiontaking - CAST(ISNULL(epositiontaking, 0) AS DECIMAL(9,8))) - scomm  + scomm * CAST(ISNULL(epositiontaking, 0) AS DECIMAL(9,8)) / (1 - tpositiontaking)) * actualrate END
				,CAST(CASE WHEN b.bettype = 29 AND b.betteam= N'1' AND b.oddsspread = 1 THEN 1 ELSE 0 END AS BIT) AS IsGOF
			FROM dbo.rmBettrans b WITH (NOLOCK)
				INNER JOIN #bettype bt ON b.bettype = bt.bettype
				INNER JOIN #tmpSelection s ON b.hdp2 = s.selection
				INNER JOIN #tmpSport sp ON b.transid2 = sp.sporttype
			WHERE winlostdate BETWEEN @f_date AND @t_date
				AND custid = @custid
				AND statusID IN (112, 113)
				AND 1 = CASE
								WHEN b.bettype = 29 AND @ComboType IN (1, 2, 3, 4, 5, 6) THEN CASE
									WHEN @ComboType = 1 AND b.betteam = N'1' AND (b.oddsspread <> 1 OR b.oddsspread IS NULL) THEN 1
									WHEN @ComboType = 2 AND b.betteam <> N'1' THEN 1
									WHEN @ComboType = 3 AND b.betteam = N'1' AND b.oddsspread = 1 THEN 1
									WHEN @ComboType = 4 AND b.betteam = N'1' THEN 1
									WHEN @ComboType = 5 AND (b.betteam <> N'1' OR (b.betteam = N'1' AND b.oddsspread = 1)) THEN 1
									WHEN @ComboType = 6 AND (b.betteam <> N'1' OR (b.betteam = N'1' AND (b.oddsspread <> 1 OR b.oddsspread IS NULL))) THEN 1
									ELSE 0 END
							ELSE 1 END
				AND (CASE WHEN b.bettype = 29 THEN b.livehomescore ELSE b.liveindicator END = @LiveStatus OR @LiveStatus = 3)
		END

		-- bettrans14
		IF @FromDate <= @MoveBetsDay
		BEGIN
			SELECT	@f_date = @FromDate
					,@t_date = CASE WHEN @ToDate > @MoveBetsDay THEN @MoveBetsDay ELSE @ToDate END
			
			INSERT INTO #tmpBettrans
			(
				transid, refno, sporttype, bettype, combo, TotalCombo, ParlayType, stake, winlost, company_winlost, stake_baseRM, winlost_baseRM, company_winlost_baseRM, IsGOF
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
				,CAST(CASE WHEN b.bettype = 29 AND b.betteam= N'1' AND b.oddsspread = 1 THEN 1 ELSE 0 END AS BIT) AS IsGOF
			FROM dbo.rmBettrans_old b WITH (NOLOCK)
				INNER JOIN #bettype bt ON b.bettype = bt.bettype
				INNER JOIN #tmpSelection s ON b.hdp2 = s.selection
				INNER JOIN #tmpSport sp ON b.transid2 = sp.sporttype
			WHERE winlostdate BETWEEN @f_date AND @t_date
				AND custid = @custid
				AND statusID IN (112, 113)
				AND 1 = CASE
							WHEN b.bettype = 29 AND @ComboType IN (1, 2, 3, 4, 5, 6) THEN CASE
									WHEN @ComboType = 1 AND b.betteam = N'1' AND (b.oddsspread <> 1 OR b.oddsspread IS NULL) THEN 1
									WHEN @ComboType = 2 AND b.betteam <> N'1' THEN 1
									WHEN @ComboType = 3 AND b.betteam = N'1' AND b.oddsspread = 1 THEN 1
									WHEN @ComboType = 4 AND b.betteam = N'1' THEN 1
									WHEN @ComboType = 5 AND (b.betteam <> N'1' OR (b.betteam = N'1' AND b.oddsspread = 1)) THEN 1
									WHEN @ComboType = 6 AND (b.betteam <> N'1' OR (b.betteam = N'1' AND (b.oddsspread <> 1 OR b.oddsspread IS NULL))) THEN 1
									ELSE 0 END
							ELSE 1 END
				AND (CASE WHEN b.bettype = 29 THEN b.livehomescore ELSE b.liveindicator END = @LiveStatus OR @LiveStatus = 3)

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
		,b.IsGOF
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