/*<info serverAlias="DBRMS-bodb_RMS" executers="wsv_rms" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[RMS_Rpt_ParlayWon]
	@FromDate		SMALLDATETIME
	,@ToDate		SMALLDATETIME
	,@MoveBetsDay	SMALLDATETIME
	,@ParlayType	VARCHAR(100) = ''
	,@Selection		VARCHAR(MAX) = ''
	,@Level			VARCHAR(100) = ''
	,@Sporttype		VARCHAR(100) = ''
	,@FromHouseAmt	MONEY = 5000
	,@SortById		TINYINT = 1
	,@IsSortAsc		BIT = 0
	,@PageIndex		INT = 1
	,@PageSize		INT = 100 -- = 0 --> all data (export excel)
	,@TotalRows		INT = 0 OUTPUT
	,@Currency		VARCHAR(MAX) = ''
	,@Site			TINYINT = 2
	,@LiveStatus	TINYINT = 3
	,@CustomerClass	SMALLINT = NULL
	,@IP			VARCHAR(45) = NULL
	,@LeagueGroup	VARCHAR(MAX) = ''
AS
/*
	Created: 20200512@Percy
	DB: DBRMS-bodb_RMS
	Task: Parlay Won Report
	
	Revisions:
		- 20200512@Percy: Initialize SP [RedmineID: #130275]
		- 20201216@Danny: Add order by Odds[RedmineID: #146929]
		- 20201204@Danny: Separate Data of Virtual Soccer & Virtual Basketball  [RedmineID: #145926]
		- 20210218@Danny: Monitor Performance of GOF  [RedmineID: #149966]
		- 20210303@Danny: Filter by Currency  [RedmineID: #148137]
		- 20210428@Danny: Add filtering by Site, Live status[RedmineID: #153874]
		- 20210629@Danny: Add filtering by Customer Class[RedmineID: #156980]
		- 20211001@Danny: Change dataType to support IPv6 [RedmineID: #162348]
		- 20230420@Cherry: Add Site column (#186735)
		- 20231020@Cherry: Parlay Generator (#195498)
		- 20231115@Cherry: Add param IP (#196550)
		- 20231201@Cherry: Parlay Type for Parlay Boost (#197680)
		- 20240115@Cherry: Change attribute for Parlay Generator (#199766)
		- 20240312@Cherry: Change SQL account in metadata (#202012)
		- 20240826@Cherry: Add filter @LeagueGroups (#209293)
		- 20241212@Cherry: Separate Cricket (#214664)
		- 20250306@Cherry: Remove @ToHouseAmt (#218958)
		- 20250410@Cherry: Upgrade ExchangeID (#222189)
		- 20251016@Cherry: Move sites NovaCasino, SEAL888 from Deposit to Credit (#241763)
		- 20251020@Cherry: Integrate Hybrid Parlay (#242165)

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
					. '-4': Saba soccer
					. '-5': Saba basketball
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
					. 5: GOF
					. 6: Parlay Generator
					. 7: Parlay Boost
					. 8: Hybrid Parlay

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

		 - @@LiveStatus:
					. Non live : 0, 
					. Live : 1, 
					. Mix Live and Non live: 2
					. All : 3
*/

BEGIN
	SET NOCOUNT ON

	--Site
	BEGIN
		CREATE TABLE #SiteTab (SiteName NVARCHAR(50), IsDeposit BIT)

		INSERT INTO #SiteTab(SiteName, IsDeposit)
		SELECT Site, CASE WHEN Site IN ('Saba789','NovaCasino','SEAL888')  THEN 0 ELSE isDeposit END
		FROM bodb02.dbo.Site (NOLOCK)
	END

	-- currency
	BEGIN
		DECLARE @tmpCurrency TABLE (currency SMALLINT)
		INSERT INTO @tmpCurrency (currency)
		SELECT val FROM dbo.f_RMS_strSplit(@Currency, ',')
	END

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
			WHERE SportType NOT IN (1,2,3,4,5,6,7,8,9,11,43,44,50)
				AND SportType <= 99
	END

	-- League Group
	CREATE TABLE #tmpLeagueGroup (LeagueGroupId INT)
	INSERT INTO #tmpLeagueGroup (LeagueGroupId)
	SELECT value FROM STRING_SPLIT(@LeagueGroup, ',')

	CREATE TABLE #tmpLeague (LeagueID INT)
	INSERT INTO #tmpLeague (LeagueID)
	SELECT LeagueID 
	FROM  dbo.rmLeague  t WITH(NOLOCK)
		INNER JOIN #tmpLeagueGroup tb ON t.GroupId = tb.LeagueGroupId

	IF EXISTS (SELECT 1 FROM #tmpLeagueGroup WHERE LeagueGroupId = -1)
	BEGIN
		INSERT INTO #tmpLeague (LeagueID)
		SELECT l.LeagueID 
		FROM   bodb02.dbo.League  l WITH(NOLOCK)
			LEFT JOIN dbo.rmLeague  t WITH(NOLOCK) ON l.leagueid = t.LeagueId
		WHERE t.LeagueId IS NULL
	END

	-- get data
	BEGIN
		DECLARE @bettypes VARCHAR(MAX)

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
	
		IF ',' + @ParlayType + ',' LIKE '%,1,%' OR ',' + @ParlayType + ',' LIKE '%,2,%' OR ',' + @ParlayType + ',' LIKE '%,5,%' OR ',' + @ParlayType + ',' LIKE '%,6,%' OR ',' + @ParlayType + ',' LIKE '%,7,%' OR ',' + @ParlayType + ',' LIKE '%,8,%'
		BEGIN
			INSERT INTO #bettype (bettype)
			VALUES (29)			
		END

		-- Single match parlay
		IF ',' + @ParlayType + ',' LIKE '%,3,%'
			INSERT INTO #bettype (bettype) VALUES (38)

		-- Penalty shootout combo
		IF ',' + @ParlayType + ',' LIKE '%,4,%'
			INSERT INTO #bettype (bettype) VALUES (376)

		DECLARE @FDate SMALLDATETIME, @TDate SMALLDATETIME

		CREATE TABLE #tmpBettrans
		(
			transid BIGINT,
			bac INT
		)

		CREATE TABLE #bettransm (transid BIGINT)

		CREATE TABLE #rmBettrans
		(
			transdate			DATETIME
			,transid			BIGINT
			,refno				BIGINT
			,custid				INT
			,SiteGroup			VARCHAR(10)
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
			,IP					VARCHAR(45)
			,currencyName		NVARCHAR(50)
			,CustomerClass		SMALLINT
			,IsParlayGenerator  BIT
			,IsBoostBonus		BIT
			,matchid			INT
		)

		IF @ToDate > @MoveBetsDay
		BEGIN
			SELECT	@FDate = CASE WHEN @FromDate <= @MoveBetsDay THEN DATEADD(DAY, 1, @MoveBetsDay) ELSE @FromDate END
					,@TDate = @ToDate
			
			INSERT INTO #tmpBettrans(transid, bac)
			SELECT transid,
				ISNULL(TRY_CAST(TRY_CAST(ExtraInfo AS XML).value('(/p1/@bac)[1]', 'VARCHAR(50)') AS INT),0)
			FROM 
				dbo.rmBettrans WITH (NOLOCK)
			WHERE winlostdate BETWEEN @FDate AND @TDate
				AND statusID = 112
				AND currency <> 20
				AND bettype = 29 
				AND betteam = N'1'
		
			INSERT INTO #rmBettrans
			(
				transdate,transid,refno,custid,SiteGroup,username,bettype,odds,Stake,StakeAfterPT,WinningAmount,HouseLoseAmount,TotalBet,TotalSelection,SportType,IP,currencyName,CustomerClass,IsParlayGenerator,IsBoostBonus,matchid
			)
			SELECT
				transdate,transid,refno,custid,SiteGroup,username,bettype,odds,Stake,StakeAfterPT,WinningAmount,HouseLoseAmount,TotalBet,TotalSelection,SportType,IP,currencyName,CustomerClass,IsParlayGenerator,IsBoostBonus,matchid
			FROM
			(
				SELECT
					b.transdate
					,b.transid
					,b.refno
					,b.custid
					,CASE WHEN st.isDeposit = 0 OR st.site IN ('Saba789','NovaCasino','SEAL888') THEN 'C' ELSE 'L' END SiteGroup
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
					,b.CurrencyName
					,ci.CustomerClass
					,CASE WHEN b.bettype = 29 AND b.betteam = N'1' AND t.bac|16 = t.bac THEN 1 ELSE 0 END IsParlayGenerator
					,CASE WHEN b.bettype = 29 AND b.betteam = N'1' AND b.oddsspread = 2 THEN 1 ELSE 0 END IsBoostBonus
					,b.matchid
				FROM dbo.rmBettrans b WITH (NOLOCK)
					INNER JOIN #bettype bt ON b.bettype = bt.bettype
					CROSS APPLY (SELECT TOP 1 s.selection FROM @tmpSelection s WHERE b.hdp2 = s.selection) s
					CROSS APPLY (SELECT TOP 1 sp.sporttype FROM @tmpSport sp WHERE b.transid2 = sp.sporttype) sp
					CROSS APPLY (SELECT TOP 1 tc.currency FROM @tmpCurrency tc WHERE b.currency = tc.currency) tc
					INNER JOIN bodb02.dbo.Customer ct WITH(NOLOCK) ON b.custid = ct.custid
					INNER JOIN bodb02.dbo.CustInfo ci WITH(NOLOCK) ON b.custid = ci.custid
					INNER JOIN bodb02.dbo.Site st WITH(NOLOCK) ON ct.site = st.site
					LEFT JOIN #tmpBettrans t ON b.transid = t.transid					
				WHERE b.winlostdate BETWEEN @FDate AND @TDate					
					AND b.statusID = 112
					AND b.currency <> 20
					AND ((winlost - actual_stake) * (1 - b.tpositiontaking - CONVERT(DECIMAL(9, 8), ISNULL(b.epositiontaking, 0))) + scomm - CASE WHEN tpositiontaking = 1 THEN 0 ELSE scomm * CONVERT(DECIMAL(9, 8), ISNULL(b.epositiontaking, 0)) / (1 - tpositiontaking) END) * actualrate >= @FromHouseAmt
					AND (b.bettype <> 29
						OR (EXISTS(SELECT TOP 1 1 FROM #ParlayType WHERE ParlayType = 1)
							AND b.bettype = 29 AND b.betteam = N'1')
						OR (EXISTS(SELECT TOP 1 1 FROM #ParlayType WHERE ParlayType = 2)
							AND b.bettype = 29 AND b.betteam <> N'1')
						OR (EXISTS(SELECT TOP 1 1 FROM #ParlayType WHERE ParlayType = 5)
							AND b.bettype = 29 AND b.betteam = N'1' AND b.oddsspread = 1)
						OR (EXISTS(SELECT TOP 1 1 FROM #ParlayType WHERE ParlayType = 6)
							AND b.bettype = 29 AND b.betteam = N'1' AND t.bac|16 = t.bac)
						OR (EXISTS(SELECT TOP 1 1 FROM #ParlayType WHERE ParlayType = 7)
							AND b.bettype = 29 AND b.betteam = N'1' AND b.oddsspread = 2)
						OR (EXISTS(SELECT TOP 1 1 FROM #ParlayType WHERE ParlayType = 8)
							AND b.bettype = 29 AND b.betteam = N'1' AND b.oddsspread = 3)
						)		
					AND ct.Site IN (SELECT SiteName FROM #SiteTab WHERE IsDeposit = CASE WHEN @Site = 2 THEN IsDeposit ELSE @Site END)
					AND (CASE WHEN b.bettype = 29 THEN b.livehomescore ELSE b.liveindicator END = @LiveStatus OR @LiveStatus = 3)
					AND (ci.CustomerClass = @CustomerClass OR @CustomerClass IS NULL)
					AND (b.IP = @IP OR @IP IS NULL)
			) r

		END

		IF @FromDate <= @MoveBetsDay
		BEGIN
			SELECT	@FDate = @FromDate
					,@TDate = CASE WHEN @ToDate > @MoveBetsDay THEN @MoveBetsDay ELSE @ToDate END

			INSERT INTO #tmpBettrans(transid, bac)
			SELECT transid,
				ISNULL(TRY_CAST(TRY_CAST(ExtraInfo AS XML).value('(/p1/@bac)[1]', 'VARCHAR(50)') AS INT),0)
			FROM 
				dbo.rmBettrans_Old WITH (NOLOCK)
			WHERE winlostdate BETWEEN @FDate AND @TDate
				AND statusID = 112
				AND currency <> 20
				AND bettype = 29 
				AND betteam = N'1'
			
			INSERT INTO #rmBettrans
			(
				transdate,transid,refno,custid,SiteGroup,username,bettype,odds,Stake,StakeAfterPT,WinningAmount,HouseLoseAmount,TotalBet,TotalSelection,SportType,IP,currencyName,CustomerClass,IsParlayGenerator,IsBoostBonus,matchid
			)
			SELECT
				transdate,transid,refno,custid,SiteGroup,username,bettype,odds,Stake,StakeAfterPT,WinningAmount,HouseLoseAmount,TotalBet,TotalSelection,SportType,IP,currencyName,CustomerClass,IsParlayGenerator,IsBoostBonus,matchid
			FROM
			(
				SELECT
					b.transdate
					,b.transid
					,b.refno
					,b.custid
					,CASE WHEN st.isDeposit = 0 OR st.site IN ('Saba789','NovaCasino','SEAL888') THEN 'C' ELSE 'L' END SiteGroup
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
					,b.CurrencyName
					,ci.CustomerClass
					,CASE WHEN b.bettype = 29 AND b.betteam = N'1' AND t.bac|16 = t.bac THEN 1 ELSE 0 END IsParlayGenerator
					,CASE WHEN b.bettype = 29 AND b.betteam = N'1' AND b.oddsspread = 2 THEN 1 ELSE 0 END IsBoostBonus
					,b.matchid
				FROM dbo.rmBettrans_Old b WITH (NOLOCK)
					INNER JOIN #bettype bt ON b.bettype = bt.bettype
					CROSS APPLY (SELECT TOP 1 s.selection FROM @tmpSelection s WHERE b.hdp2 = s.selection) s
					CROSS APPLY (SELECT TOP 1 sp.sporttype FROM @tmpSport sp WHERE b.transid2 = sp.sporttype) sp
					CROSS APPLY (SELECT TOP 1 tc.currency FROM @tmpCurrency tc WHERE b.currency = tc.currency) tc
					INNER JOIN bodb02.dbo.Customer ct WITH(NOLOCK) ON b.custid = ct.custid
					INNER JOIN bodb02.dbo.CustInfo ci WITH(NOLOCK) ON b.custid = ci.custid
					INNER JOIN bodb02.dbo.Site st WITH(NOLOCK) ON ct.site = st.site
					LEFT JOIN #tmpBettrans t ON b.transid = t.transid
				WHERE b.winlostdate BETWEEN @FDate AND @TDate					
					AND b.statusID = 112
					AND b.currency <> 20
					AND ((winlost - actual_stake) * (1 - b.tpositiontaking - CONVERT(DECIMAL(9, 8), ISNULL(b.epositiontaking, 0))) + scomm - CASE WHEN tpositiontaking = 1 THEN 0 ELSE scomm * CONVERT(DECIMAL(9, 8), ISNULL(b.epositiontaking, 0)) / (1 - tpositiontaking) END) * actualrate >= @FromHouseAmt
					AND (b.bettype <> 29
						OR (EXISTS(SELECT TOP 1 1 FROM #ParlayType WHERE ParlayType = 1)
							AND b.bettype = 29 AND b.betteam = N'1')
						OR (EXISTS(SELECT TOP 1 1 FROM #ParlayType WHERE ParlayType = 2)
							AND b.bettype = 29 AND b.betteam <> N'1')
						OR (EXISTS(SELECT TOP 1 1 FROM #ParlayType WHERE ParlayType = 5)
							AND b.bettype = 29 AND b.betteam = N'1' AND b.oddsspread = 1)
						OR (EXISTS(SELECT TOP 1 1 FROM #ParlayType WHERE ParlayType = 6)
							AND b.bettype = 29 AND b.betteam = N'1' AND t.bac|16 = t.bac)
						OR (EXISTS(SELECT TOP 1 1 FROM #ParlayType WHERE ParlayType = 7)
							AND b.bettype = 29 AND b.betteam = N'1' AND b.oddsspread = 2)
						OR (EXISTS(SELECT TOP 1 1 FROM #ParlayType WHERE ParlayType = 8)
							AND b.bettype = 29 AND b.betteam = N'1' AND b.oddsspread = 3)
						)		
					AND ct.Site IN (SELECT SiteName FROM #SiteTab WHERE IsDeposit = CASE WHEN @Site = 2 THEN IsDeposit ELSE @Site END)
					AND (b.livehomescore = @LiveStatus OR @LiveStatus = 3)
					AND (ci.CustomerClass = @CustomerClass OR @CustomerClass IS NULL)
					AND (b.IP = @IP OR @IP IS NULL)
			) r
			
		END

	END

	INSERT INTO #bettransm (transid)
	SELECT transid
	FROM #rmBettrans b
		INNER JOIN bodb02.dbo.match m WITH (NOLOCK) ON b.matchid = m.matchid
	WHERE b.bettype IN (38, 376)
		AND m.leagueid IN (SELECT LeagueID FROM #tmpLeague)

	INSERT INTO #bettransm (transid)
	SELECT transid
	FROM #rmBettrans b
		INNER JOIN bodb02.dbo.match14 m WITH (NOLOCK) ON b.matchid = m.matchid
	WHERE b.bettype IN (38, 376)
		AND m.leagueid IN (SELECT LeagueID FROM #tmpLeague)
		AND b.transid NOT IN (SELECT transid FROM #bettransm)

	INSERT INTO #bettransm (transid)
	SELECT transid
	FROM #rmBettrans b
		INNER JOIN dbo.rmMatch_bk m WITH (NOLOCK) ON b.matchid = m.matchid
	WHERE b.bettype IN (38, 376)
		AND m.leagueid IN (SELECT LeagueID FROM #tmpLeague)
		AND b.transid NOT IN (SELECT transid FROM #bettransm)

	INSERT INTO #bettransm (transid)
    SELECT b.transid			
	FROM #rmBettrans b
		INNER JOIN bodb02.dbo.bettransm bm WITH (NOLOCK) ON b.refno = bm.refno
		INNER JOIN bodb02.dbo.match m WITH (NOLOCK) ON bm.matchid = m.matchid
	WHERE b.bettype = 29		
		AND m.leagueid IN (SELECT LeagueID FROM #tmpLeague)
	UNION 
	SELECT b.transid		
	FROM #rmBettrans b
		INNER JOIN bodb02.dbo.bettransm14 bm WITH (NOLOCK) ON b.refno = bm.refno
		INNER JOIN bodb02.dbo.match14 m WITH (NOLOCK) ON bm.matchid = m.matchid
	WHERE b.bettype = 29
		AND m.leagueid IN (SELECT LeagueID FROM #tmpLeague)
	UNION 
	SELECT b.transid					
	FROM #rmBettrans b
		INNER JOIN dbo.rmBettransm_bk bm WITH (NOLOCK) ON b.refno = bm.refno
		INNER JOIN dbo.rmMatch_bk m WITH (NOLOCK) ON bm.matchid = m.matchid
	WHERE b.bettype = 29
		AND m.leagueid IN (SELECT LeagueID FROM #tmpLeague)

	DELETE FROM #rmBettrans
	WHERE transid NOT IN (SELECT transid FROM #bettransm)

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

		DECLARE @SQL NVARCHAR(MAX)
		SELECT  @SQL = 'CREATE INDEX IX_Index ON #rmBettrans (' + @sortedColumn + ')' + CHAR(13)
		SELECT  @SQL = @SQL
						+  'SELECT transdate,transid,refno,custid,SiteGroup,username,bettype,odds,Stake,StakeAfterPT,WinningAmount,HouseLoseAmount,TotalBet,TotalSelection,SportType,IP, currencyName, CustomerClass, IsParlayGenerator, IsBoostBonus
							FROM
							(
								SELECT ROW_NUMBER() OVER(ORDER BY b.' + @sortedColumn + CASE WHEN @IsSortAsc = 0 THEN ' DESC' ELSE ' ' END + ',transdate) AS rn,
									b.transdate,b.transid,b.refno,b.custid,b.SiteGroup,b.username,b.bettype,b.odds,b.Stake,b.StakeAfterPT,b.WinningAmount,b.HouseLoseAmount,b.TotalBet,b.TotalSelection,b.SportType,b.IP, b.currencyName, b.CustomerClass, b.IsParlayGenerator, b.IsBoostBonus								
								FROM #rmBettrans b
									LEFT JOIN dbo.rmCustomer c WITH (NOLOCK) ON b.custid = c.custid
								WHERE ISNULL(c.level, 0) IN (SELECT level FROM #level)
							) b
							WHERE rn BETWEEN ' + CONVERT(VARCHAR(10), @RowStart) + ' AND ' + CONVERT(VARCHAR(10), @RowEnd)

		EXECUTE sp_executesql @SQL
	END

	DROP TABLE #level
	DROP TABLE #rmBettrans
	DROP TABLE #bettype
	DROP TABLE #ParlayType
	DROP TABLE #tmpBettrans
	DROP TABLE #SiteTab
	DROP TABLE #bettransm
	DROP TABLE #tmpLeague
	DROP TABLE #tmpLeagueGroup

END
GO