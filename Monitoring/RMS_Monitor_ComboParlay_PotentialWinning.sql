/*<info serverAlias="DBRMS-bodb_RMS" executers="bodbRMSNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[RMS_Monitor_ComboParlay_PotentialWinning]
	@selection		VARCHAR(MAX) = '',
	@sporttype		VARCHAR(100) = '',
	@level			VARCHAR(100) = '',
	@WinningAmount	MONEY = 0,
	@limitRowCount	INT = 100,
	@ParlayType		VARCHAR(10)  = '',
	@IsCornerParlay BIT = 0,
	@IsAgentView	BIT = 0,
	@Recommend		INT = NULL
AS

/*
	Created: 20160427@Winnie
	DB: DBRMS-bodb_RMS
	Task: Monitoring Total Potential Winning by member

	Revisions:
		- 20170719@Winnie: Add MuayThai RedmineID: #79500
		- 20171219@Vicky: Add column currency [RedmineID: #88400]
		- 20190214@Jacob: Add Bet Builder RedmineID: #108694
		- 20200510@Percy: Add Penalty Shootout Combo [RedmineID: #133961]
		- 20201211@Danny: Monitor Corner Parlay Tickets [RedmineID: #146929]
		- 20201226@Sophia: Workaround for performance issue [RedmineID: #146929]
		- 20210218@Danny: Monitor Performance of GOF  [RedmineID: #149966]
		- 20210302@Danny: Changes on Potential Winning Monitor Tool [RedmineID: #146930]

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
		- @ParlayType:
					. 1: Mix parlay
					. 2: Combo parlay
					. 3: Single Match Parlay
					. 4: Panalty shootout combo
					. 5: GOF
		
*/

BEGIN
	SET NOCOUNT ON

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

		CREATE TABLE #bettrans_details(
			refno BIGINT, 
			bettype SMALLINT, 
			transid BIGINT,
			custID INT,
			username NVARCHAR(50),
			betteam NVARCHAR(10),
			CurrencyName NVARCHAR(50),
			Odds MONEY,
			stake MONEY,
			WinningAmount MONEY,
			CompanyLoseAmount MONEY,
			transdate DATETIME,
			recommend INT,
			level TINYINT,
			oddsspread SMALLMONEY
		)

	

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

			SELECT	@ComboType = CASE	WHEN COUNT(DISTINCT val) = 3 AND SUM(DISTINCT CAST(val as SMALLINT)) = 8 THEN 7 
										WHEN COUNT(DISTINCT val) = 2 AND SUM(DISTINCT CAST(val as SMALLINT)) = 3 THEN 6
										WHEN COUNT(DISTINCT val) = 2 AND SUM(DISTINCT CAST(val as SMALLINT)) = 6 THEN 4
										WHEN COUNT(DISTINCT val) = 2 AND SUM(DISTINCT CAST(val as SMALLINT)) = 7 THEN 5
										WHEN COUNT(DISTINCT val) = 1 AND SUM(DISTINCT CAST(val as SMALLINT)) = 1 THEN 1
										WHEN COUNT(DISTINCT val) = 1 AND SUM(DISTINCT CAST(val as SMALLINT)) = 2 THEN 2
										WHEN COUNT(DISTINCT val) = 1 AND SUM(DISTINCT CAST(val as SMALLINT)) = 5 THEN 3
								END
			FROM dbo.f_RMS_strSplit(@ParlayType, ',') WHERE val IN (1,2,5)
		END

		-- Single match parlay
		IF ',' + @ParlayType + ',' LIKE '%,3,%'
			INSERT INTO #bettype (bettype)
			VALUES (38)

		-- Penalty shootout combo
		IF ',' + @ParlayType + ',' LIKE '%,4,%'
			INSERT INTO #bettype (bettype)
			VALUES (376)

		IF @Recommend > 0 and @IsAgentView = 0
		BEGIN
			
			CREATE TABLE #rmTransRecommend (transid BIGINT)

			INSERT INTO #rmTransRecommend(transid) 
			SELECT  transid FROM dbo.rmBettrans b WITH (NOLOCK) 
			WHERE recommend = @Recommend

			INSERT INTO #bettrans_details(refno,bettype,transid,custID,username,betteam,CurrencyName,Odds,stake,WinningAmount,CompanyLoseAmount, transdate,recommend,level,oddsspread)
			SELECT	b.refno, 
					b.bettype, 
					b.transid,
					b.custID,
					b.username, 
					b.betteam, 
					b.CurrencyName,
					b.odds2 * b.TotalBet as Odds,
					b.stake * b.actualrate as stake,
					(b.odds2 - 1) * b.stake * b.actualrate as WinningAmount,
					(b.odds2 - 1) * b.stake * b.actualrate * (1 - b.tpositiontaking) as CompanyLoseAmount,
					b.transdate,
					b.recommend,
					ISNULL(mc.level,0),
					b.oddsspread
			FROM #rmTransRecommend tmp
				INNER JOIN dbo.rmBettrans b WITH (NOLOCK, INDEX = CIX_rmBettrans, FORCESEEK) ON tmp.transid = b.transid
				INNER JOIN #bettype bt ON b.bettype = bt.bettype
				INNER JOIN #tmpSelection s ON b.hdp2 = s.selection
				INNER JOIN #tmpSport sp ON b.transid2 = sp.sporttype
				LEFT JOIN rmCustomer mc WITH (NOLOCK) ON b.custid = mc.custid
			WHERE b.statusID = 0
				AND b.currency <> 20

			DROP TABLE #rmTransRecommend
		END
		ELSE
		BEGIN
			INSERT INTO #bettrans_details(refno,bettype,transid,custID,username,betteam,CurrencyName,Odds,stake,WinningAmount,CompanyLoseAmount, transdate,recommend,level,oddsspread)
			SELECT	b.refno, 
					b.bettype, 
					b.transid,
					b.custID,
					b.username, 
					b.betteam, 
					b.CurrencyName,
					b.odds2 * b.TotalBet as Odds,
					b.stake * b.actualrate as stake,
					(b.odds2 - 1) * b.stake * b.actualrate as WinningAmount,
					(b.odds2 - 1) * b.stake * b.actualrate * (1 - b.tpositiontaking) as CompanyLoseAmount,
					b.transdate,
					b.recommend,
					ISNULL(mc.level,0),
					b.oddsspread
			FROM dbo.rmBettrans b WITH (NOLOCK)
				INNER JOIN #bettype bt ON b.bettype = bt.bettype
				INNER JOIN #tmpSelection s ON b.hdp2 = s.selection
				INNER JOIN #tmpSport sp ON b.transid2 = sp.sporttype
				LEFT JOIN rmCustomer mc WITH (NOLOCK) ON b.custid = mc.custid
			WHERE b.statusID = 0
				AND b.currency <> 20
		END


		IF @IsCornerParlay = 1
		BEGIN
			CREATE TABLE #bettransm(
			transid BIGINT,
			CornerParlay INT
			)

			INSERT INTO #bettransm (transid, CornerParlay)
			SELECT b.transid, COUNT(1) AS CornerParlay
			FROM #bettrans_details b WITH(NOLOCK)
			INNER JOIN  bodb02.dbo.bettransm bm WITH (NOLOCK, INDEX = IX_bettransm) ON b.refno = bm.refno
			INNER JOIN bodb02.dbo.match m WITH (NOLOCK) ON bm.matchid = m.matchid
			WHERE m.ChildMatchType = 204
			GROUP BY b.transid 	 	


			INSERT INTO #bettransm (transid, CornerParlay)
			SELECT  b.transid, COUNT(1) AS CornerParlay
			FROM #bettrans_details b WITH(NOLOCK)
			INNER JOIN  bodb02.dbo.bettransm14 bm WITH (NOLOCK, INDEX = IX_bettransm14) ON b.refno = bm.refno
			INNER JOIN bodb02.dbo.match m WITH (NOLOCK) ON bm.matchid = m.matchid
			WHERE m.ChildMatchType = 204
			GROUP BY b.transid 		

			SELECT	transid, SUM(CornerParlay) CornerParlay
			INTO	#bettransmSummary
			FROM	#bettransm
			GROUP BY transid

			
			CREATE CLUSTERED INDEX #cix_bettransmSummary ON #bettransmSummary (transid)

			DELETE t
			FROM #bettrans_details t
			WHERE  NOT EXISTS (SELECT 1 FROM #bettransmSummary x WHERE  x.transid = t.transid)

			DROP TABLE #bettransm

		END

		DROP TABLE #bettype
		DROP TABLE #tmpSelection
		DROP TABLE #tmpSport
		
	END

	-- Return data
	BEGIN
		CREATE TABLE #level (level TINYINT)
		INSERT INTO #level (level)
		SELECT DISTINCT val FROM dbo.f_RMS_strSplit(@level, ',')

		IF @IsAgentView = 0
		BEGIN

		IF @Recommend > 0 
		BEGIN
			SET @limitRowcount = 1000000
		END

			SELECT TOP(@limitRowcount) 
				MAX(b.transdate) AS transdate
				,b.custid
				,b.username
				,AVG(b.Odds) AS Odds
				,SUM(b.stake) AS stake
				,SUM(b.WinningAmount) AS WinningAmount
				,SUM(b.CompanyLoseAmount) AS CompanyLoseAmount
				,COUNT(1) AS TotalBets
				,b.level  AS level
				,b.CurrencyName AS currency
			FROM #bettrans_details b WITH(NOLOCK)
			WHERE
				b.level IN(SELECT level FROM #level)
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

			GROUP BY
				b.custid
				,b.username 
				,b.level 
				,b.CurrencyName
			HAVING SUM(b.WinningAmount) >= CASE WHEN @Recommend >0 THEN 0 ELSE @WinningAmount END
			ORDER BY WinningAmount DESC

		
		END
		ELSE
		BEGIN
			SELECT TOP (@limitRowcount)
				mc.username AgentName
				,SUM(stake) TotalStake
				,SUM(b.WinningAmount) AS WinningAmount
				,COUNT(DISTINCT b.custid) TotalMember
				,b.recommend
			FROM  #bettrans_details b WITH(NOLOCK) 
			LEFT JOIN bodb02.dbo.custInfo  mc WITH (NOLOCK)  ON b.recommend = mc.custid
			WHERE
			b.level IN(SELECT level FROM #level)
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
			GROUP BY
				mc.username
				,b.recommend
			HAVING SUM(b.WinningAmount) >= @WinningAmount
			ORDER BY WinningAmount DESC
			
		END


	END
	
	DROP TABLE #bettrans_details
END
GO