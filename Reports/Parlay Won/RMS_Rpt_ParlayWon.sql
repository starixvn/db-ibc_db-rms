/*<info serverAlias="DBRMS-bodb_RMS" executers="bodbRMSNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[RMS_Rpt_ParlayWon]
	@FromDate		SMALLDATETIME
	,@ToDate		SMALLDATETIME
	,@MoveBetsDay	SMALLDATETIME
	,@ParlayType	VARCHAR(100) = ''
	,@Selection		VARCHAR(MAX) = ''
	,@Level			VARCHAR(100) = ''
	,@Sporttype		VARCHAR(100) = ''
	,@FromHouseAmt	MONEY = 5000
	,@ToHouseAmt	MONEY = 10000
	,@SortById		TINYINT = 1
	,@IsSortAsc		BIT = 0
	,@PageIndex		INT = 1
	,@PageSize		INT = 100 -- = 0 --> all data (export excel)
	,@TotalRows		INT = 0 OUTPUT
AS
/*
	Created: 20200512@Percy
	DB: DBRMS-bodb_RMS
	Task: Parlay Won Report
	
	Revisions:
		- 20200512@Percy: Initialize SP [RedmineID: #130275]
		- 20201216@Danny: Add order by Odds[RedmineID: #146929]
	
	Parameter's Explanation:
		- @selection:
					. '2,3': 2,3 selections
					. '10': 10 UP
					. '0' : All
		- @sporttype:
					. '1': soccer only
					. '-1': Combined other sports
					. '-2': Other sports
					. '-3': Combined sports
		- @level:
					. '0': none
					. '1,2,3': level 1,2,3
		- @Market:
					. 1: Today only maket
					. 2: Early only maket
					. 3: Combined
		- @ParlayType:
					. 1: Mix parlay
					. 2: Combo parlay
					. 3: Single Match Parlay
					. 4: Panalty shootout combo
		- @SortById: sort base on column:
					. 1: transdate
					. 2: username
					. 3: stake
					. 4: stake after PT
					. 5: winning amount
					. 6: house lose amount
		- @IsSortAsc: ascending or descending
					. 1: ascending
					. 0: descending
*/

BEGIN
	SET NOCOUNT ON

	-- selections
	BEGIN
		DECLARE @tmpSelection TABLE (selection INT)

		-- all selections (2 --> 100)
		IF ',' + @selection + ',' LIKE '%,0,%'
		BEGIN
			SELECT @selection = '2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,64,65,66,67,68,69,70,71,72,73,74,75,76,77,78,79,80,81,82,83,84,85,86,87,88,89,90,91,92,93,94,95,96,97,98,99,100'
		
			INSERT INTO @tmpSelection (selection)
			SELECT val FROM dbo.f_RMS_strSplit(@selection, ',')
		END
		-- 10UP (add 11 --> 100)
		ELSE IF ',' + @selection + ',' LIKE '%,10,%'
		BEGIN
			SELECT @selection = @selection + ',11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,64,65,66,67,68,69,70,71,72,73,74,75,76,77,78,79,80,81,82,83,84,85,86,87,88,89,90,91,92,93,94,95,96,97,98,99,100'
		
			INSERT INTO @tmpSelection (selection)
			SELECT val FROM dbo.f_RMS_strSplit(@selection, ',')
		END
		ELSE
		BEGIN
			INSERT INTO @tmpSelection (selection)
			SELECT val FROM dbo.f_RMS_strSplit(@selection, ',')
		END
	END

	-- sports
	BEGIN
		DECLARE @tmpSport TABLE (sporttype INT)
		INSERT INTO @tmpSport (sporttype)
		SELECT val FROM dbo.f_RMS_strSplit(@sporttype, ',')

		IF ',' + @sporttype + ',' LIKE '%,-2,%'
			INSERT INTO @tmpSport (sporttype)
			SELECT SportType FROM bodb02.dbo.Sports WITH (NOLOCK)
			WHERE SportType NOT IN (1,2,3,4,5,6,7,8,9,11,43,44)
				AND SportType <= 99
	END

	-- get data
	BEGIN
		DECLARE @bettypes VARCHAR(MAX)

		-- Combo parlay
		DECLARE @ComboType TINYINT = 0 -- 1: mix parlay only, 2: combo parlay only, 3: combined
		
		IF ',' + @ParlayType + ',' LIKE '%,1,%' OR ',' + @ParlayType + ',' LIKE '%,2,%'
		BEGIN
			SELECT @bettypes = COALESCE(@bettypes + ',', '') + '29'

			IF (SELECT COUNT(DISTINCT val) FROM dbo.f_RMS_strSplit(@ParlayType, ',') WHERE val IN (1,2)) = 2
				SELECT @ComboType = 3
			ELSE IF ',' + @ParlayType + ',' LIKE '%,1,%'
				SELECT @ComboType = 1
			ELSE
				SELECT @ComboType = 2
		END

		-- Single match parlay
		IF ',' + @ParlayType + ',' LIKE '%,3,%'
			SELECT @bettypes = COALESCE(@bettypes + ',', '') + '38'

		-- Penalty shootout combo
		IF ',' + @ParlayType + ',' LIKE '%,4,%'
			SELECT @bettypes = COALESCE(@bettypes + ',', '') + '376'

		DECLARE @FDate SMALLDATETIME, @TDate SMALLDATETIME

		CREATE TABLE #rmBettrans
		(
			transdate			DATETIME
			,transid			BIGINT
			,refno				BIGINT
			,custid				INT
			,username			NVARCHAR(50)
			,bettype			SMALLINT
			,odds				SMALLMONEY
			,Stake				MONEY
			,StakeAfterPT		MONEY
			,WinningAmount		MONEY
			,HouseLoseAmount	MONEY
			,TotalBet			INT
			,TotalSelection		INT
			,SportType			SMALLINT
			,IP					NVARCHAR(15)
		)

		IF @ToDate > @MoveBetsDay
		BEGIN
			SELECT	@FDate = CASE WHEN @FromDate <= @MoveBetsDay THEN DATEADD(DAY, 1, @MoveBetsDay) ELSE @FromDate END
					,@TDate = @ToDate

			INSERT INTO #rmBettrans
			(
				transdate,transid,refno,custid,username,bettype,odds,Stake,StakeAfterPT,WinningAmount,HouseLoseAmount,TotalBet,TotalSelection,SportType,IP
			)
			SELECT
				transdate,transid,refno,custid,username,bettype,odds,Stake,StakeAfterPT,WinningAmount,HouseLoseAmount,TotalBet,TotalSelection,SportType,IP
			FROM
			(
				SELECT
					b.transdate
					,b.transid
					,b.refno
					,b.custid
					,b.Username
					,b.bettype
					,(b.winlost - b.actual_stake) / b.stake AS odds
					,b.stake * b.actualrate AS Stake
					,b.stake * (1 - b.tpositiontaking - CONVERT(DECIMAL(9, 8), ISNULL(b.epositiontaking, 0))) * b.actualrate AS StakeAfterPT
					,(b.winlost - b.actual_stake) * b.actualrate AS WinningAmount
					,((winlost - actual_stake) * (1 - b.tpositiontaking - CONVERT(DECIMAL(9, 8), ISNULL(b.epositiontaking, 0))) + scomm - CASE WHEN tpositiontaking = 1 THEN 0 ELSE scomm * CONVERT(DECIMAL(9, 8), ISNULL(b.epositiontaking, 0)) / (1 - tpositiontaking) END) * actualrate AS HouseLoseAmount
					,b.TotalBet
					,b.hdp2 AS TotalSelection
					,b.transid2 AS SportType
					,b.IP
				FROM dbo.rmBettrans b WITH (NOLOCK)
					CROSS APPLY (SELECT TOP 1 s.selection FROM @tmpSelection s WHERE b.hdp2 = s.selection) s
					CROSS APPLY (SELECT TOP 1 sp.sporttype FROM @tmpSport sp WHERE b.transid2 = sp.sporttype) sp
				WHERE b.winlostdate BETWEEN @FDate AND @TDate
					AND b.bettype IN (29, 38, 376)
					AND CHARINDEX(',' + CONVERT(VARCHAR(10), b.bettype) + ',', ',' + @bettypes + ',') > 0
					AND b.statusID = 112
					AND b.currency <> 20
					AND ((winlost - actual_stake) * (1 - b.tpositiontaking - CONVERT(DECIMAL(9, 8), ISNULL(b.epositiontaking, 0))) + scomm - CASE WHEN tpositiontaking = 1 THEN 0 ELSE scomm * CONVERT(DECIMAL(9, 8), ISNULL(b.epositiontaking, 0)) / (1 - tpositiontaking) END) * actualrate >= @FromHouseAmt
					AND 1 = CASE
								WHEN b.bettype = 29 AND @ComboType IN (1, 2) THEN CASE
									WHEN @ComboType = 1 AND b.betteam = N'1' THEN 1
									WHEN @ComboType = 2 AND b.betteam <> N'1' THEN 1
									ELSE 0 END
								ELSE 1 END
			) r
			WHERE @ToHouseAmt = 0 OR HouseLoseAmount <= @ToHouseAmt
		END

		IF @FromDate <= @MoveBetsDay
		BEGIN
			SELECT	@FDate = @FromDate
					,@TDate = CASE WHEN @ToDate > @MoveBetsDay THEN @MoveBetsDay ELSE @ToDate END

			INSERT INTO #rmBettrans
			(
				transdate,transid,refno,custid,username,bettype,odds,Stake,StakeAfterPT,WinningAmount,HouseLoseAmount,TotalBet,TotalSelection,SportType,IP
			)
			SELECT
				transdate,transid,refno,custid,username,bettype,odds,Stake,StakeAfterPT,WinningAmount,HouseLoseAmount,TotalBet,TotalSelection,SportType,IP
			FROM
			(
				SELECT
					b.transdate
					,b.transid
					,b.refno
					,b.custid
					,b.Username
					,b.bettype
					,(b.winlost - b.actual_stake) / b.stake AS odds
					,b.stake * b.actualrate AS Stake
					,b.stake * (1 - b.tpositiontaking - CONVERT(DECIMAL(9, 8), ISNULL(b.epositiontaking, 0))) * b.actualrate AS StakeAfterPT
					,(b.winlost - b.actual_stake) * b.actualrate AS WinningAmount
					,((winlost - actual_stake) * (1 - b.tpositiontaking - CONVERT(DECIMAL(9, 8), ISNULL(b.epositiontaking, 0))) + scomm - CASE WHEN tpositiontaking = 1 THEN 0 ELSE scomm * CONVERT(DECIMAL(9, 8), ISNULL(b.epositiontaking, 0)) / (1 - tpositiontaking) END) * actualrate AS HouseLoseAmount
					,b.TotalBet
					,b.hdp2 AS TotalSelection
					,b.transid2 AS SportType
					,b.IP
				FROM dbo.rmBettrans_Old b WITH (NOLOCK)
					CROSS APPLY (SELECT TOP 1 s.selection FROM @tmpSelection s WHERE b.hdp2 = s.selection) s
					CROSS APPLY (SELECT TOP 1 sp.sporttype FROM @tmpSport sp WHERE b.transid2 = sp.sporttype) sp
				WHERE b.winlostdate BETWEEN @FDate AND @TDate
					AND b.bettype IN (29, 38, 376)
					AND CHARINDEX(',' + CONVERT(VARCHAR(10), b.bettype) + ',', ',' + @bettypes + ',') > 0
					AND b.statusID = 112
					AND b.currency <> 20
					AND ((winlost - actual_stake) * (1 - b.tpositiontaking - CONVERT(DECIMAL(9, 8), ISNULL(b.epositiontaking, 0))) + scomm - CASE WHEN tpositiontaking = 1 THEN 0 ELSE scomm * CONVERT(DECIMAL(9, 8), ISNULL(b.epositiontaking, 0)) / (1 - tpositiontaking) END) * actualrate >= @FromHouseAmt
					AND 1 = CASE
								WHEN b.bettype = 29 AND @ComboType IN (1, 2) THEN CASE
									WHEN @ComboType = 1 AND b.betteam = N'1' THEN 1
									WHEN @ComboType = 2 AND b.betteam <> N'1' THEN 1
									ELSE 0 END
								ELSE 1 END
			) r
			WHERE @ToHouseAmt = 0 OR HouseLoseAmount <= @ToHouseAmt
		END
	END

	-- Return data
	BEGIN
		CREATE TABLE #level (level INT)
		INSERT INTO #level (level)
		SELECT DISTINCT val FROM dbo.f_RMS_strSplit(@level, ',')

		-- Total Rows
		IF @@ROWCOUNT = 11 -- all levels
			SELECT @TotalRows = COUNT(1) FROM #rmBettrans
		ELSE
			SELECT @TotalRows = COUNT(1)
			FROM #rmBettrans b
				LEFT JOIN dbo.rmCustomer c WITH (NOLOCK) ON b.custid = c.custid
			WHERE ISNULL(c.level, 0) IN (SELECT level FROM #level)

		DECLARE @RowStart INT, @RowEnd INT

		IF @PageSize = 0 -- all data (export excel)
		BEGIN
			SELECT @RowStart	= 1
			SELECT @RowEnd		= @TotalRows
		END
		ELSE
		BEGIN
			SELECT @RowStart	= (@PageIndex - 1) * @PageSize + 1
			SELECT @RowEnd		= @RowStart + @PageSize - 1
		END

		DECLARE @sortedColumn VARCHAR(50)
		SELECT  @sortedColumn = CASE @SortById
									WHEN 1 THEN 'transdate'
									WHEN 2 THEN 'username'
									WHEN 3 THEN 'Stake'
									WHEN 4 THEN 'StakeAfterPT'
									WHEN 5 THEN 'WinningAmount'
									WHEN 6 THEN 'HouseLoseAmount'
									WHEN 7 THEN 'odds'
									ELSE 'transdate' END

		DECLARE @SQL VARCHAR(MAX)
		SELECT  @SQL = 'CREATE INDEX IX_Index ON #rmBettrans (' + @sortedColumn + ')' + CHAR(13)
		SELECT  @SQL = @SQL
						+  'SELECT transdate,transid,refno,custid,username,bettype,odds,Stake,StakeAfterPT,WinningAmount,HouseLoseAmount,TotalBet,TotalSelection,SportType,IP
							FROM
							(
								SELECT
									b.transdate,b.transid,b.refno,b.custid,b.username,b.bettype,b.odds,b.Stake,b.StakeAfterPT,b.WinningAmount,b.HouseLoseAmount,b.TotalBet,b.TotalSelection,b.SportType,b.IP
									,ROW_NUMBER() OVER(ORDER BY b.' + @sortedColumn + CASE WHEN @IsSortAsc = 0 THEN ' DESC' ELSE ' ' END + ') AS rn
								FROM #rmBettrans b
									LEFT JOIN dbo.rmCustomer c WITH (NOLOCK) ON b.custid = c.custid
								WHERE ISNULL(c.level, 0) IN (SELECT level FROM #level)
							) b
							WHERE rn BETWEEN ' + CONVERT(VARCHAR(10), @RowStart) + ' AND ' + CONVERT(VARCHAR(10), @RowEnd)

		EXEC (@SQL)
	END

	DROP TABLE #level
	DROP TABLE #rmBettrans
END
GO