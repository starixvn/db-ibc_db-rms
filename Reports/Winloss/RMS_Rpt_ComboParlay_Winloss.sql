/*<info serverAlias="DBRMS-bodb_RMS" executers="wsv_rms" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[RMS_Rpt_ComboParlay_Winloss]
	@fromdate		SMALLDATETIME,
	@todate			SMALLDATETIME,
	@movebetsday	DATETIME,
	@balanceUpday	DATETIME = NULL,
	@sporttype		VARCHAR(100) = '',
	@selection		VARCHAR(MAX) = '',
	@ParlayType		VARCHAR(100) = '',
	@ReportType		TINYINT = 1,
	@Site			TINYINT = 2,
	@LiveStatus		TINYINT = 3
AS

/*
	Created: 20160511@Winnie
	DB: DBRMS-bodb_RMS
	Task: report comboparlay winloss
		
	Revisions:	
		- 20170719@Winnie: Add MuayThai RedmineID: #79500		
		- 20180927@Jacob: Apply Extra PT and Super Comm to Report.  RedmineID: #100951 		
		- 20181010@Elodie: Enhance performance
		- 20190214@Jacob: Add Bet Builder RedmineID: #108694
		- 20191211@Jacob: Extra PT - Add new structure to support extra pt column on bettrans table #124194
		- 20200510@Percy: Add Penalty Shootout Combo [RedmineID: #133961]
		- 20201204@Danny: Separate Data of Virtual Soccer & Virtual Basketball  [RedmineID: #145926]
		- 20210218@Danny: Monitor Performance of GOF  [RedmineID: #149966]
		- 20210428@Danny: Add filtering by Site[RedmineID: #153874]
		- 20220519@Danny: add filter by Live Status [RedmineID: #172691]
		- 20231020@Cherry: Parlay Generator (#195498)
		- 20231206@Cherry: Tuning performance (#196605)
		- 20231215@Cherry: Parlay Type for Parlay Boost (#197680)
		- 20240115@Cherry: Change attribute for Parlay Generator (#199766)
		- 20240312@Cherry: Change SQL account in metadata (#202012)
		- 20241212@Cherry: Separate Cricket (#214664)
		- 20250716@Cherry: Report by Parlay Type (#232923)
		- 20251015@Cherry: Tuning performance (#241737)
		- 20251016@Cherry: Move sites NovaCasino, SEAL888 from Deposit to Credit (#241763)
	
	Parameter's Explanation:
		- @sporttype:
					. '1': soccer only
					. '-1': Combined other sports
					. '-2': Other sports
					. '-3': Combined sports
					. -4: saba soccer
					. -5: saba basketball

		- @ReportType:
					. '1': combo
					. '2': Sporttype
					. '3': Parlay Type
		- @ParlayType:
					. 1: Mix parlay
					. 2: Combo parlay
					. 3: Single Match Parlay
					. 4: Panalty shootout combo
					. 5: GOF
					. 6: Parlay Generator
					. 7: Parlay Boost

		 - @Site:
					. 0 = Credit sites
					. 1 = Deposit sites
					. 2 = All sites
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
			WHERE SportType NOT IN (1,2,3,4,5,6,7,8,9,11,43,44,50)
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
	
		IF ',' + @ParlayType + ',' LIKE '%,1,%' OR ',' + @ParlayType + ',' LIKE '%,2,%' OR ',' + @ParlayType + ',' LIKE '%,5,%' OR ',' + @ParlayType + ',' LIKE '%,6,%' OR ',' + @ParlayType + ',' LIKE '%,7,%'
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

		DECLARE @f_date SMALLDATETIME, @t_date SMALLDATETIME

		CREATE TABLE #tmpBettrans
		(
			transid BIGINT,
			bac INT
		)		

		CREATE TABLE #rptWinloss
		(
			winlostdate DATETIME,
			combo	INT,
			tickets_won	INT,
			tickets_lose INT,
			stake_won MONEY,
			stake_lose MONEY,
			member_won MONEY,
			member_lose MONEY,
			ourPT_won MONEY,
			ourPT_lose MONEY,
			sporttype INT,
			parlaytype INT
		)		

		-- rmBettrans
		IF @ToDate > @MoveBetsDay
		BEGIN
			SELECT	@f_date = CASE WHEN @FromDate <= @MoveBetsDay THEN DATEADD(DAY, 1, @MoveBetsDay) ELSE @FromDate END
					,@t_date = @ToDate			

			INSERT INTO #tmpBettrans(transid, bac)
			SELECT transid,
				ISNULL(TRY_CAST(TRY_CAST(ExtraInfo AS XML).value('(/p1/@bac)[1]', 'VARCHAR(50)') AS INT),0)
			FROM 
				dbo.rmBettrans WITH (NOLOCK)
			WHERE winlostdate BETWEEN @f_date AND @t_date
				AND statusID IN (112, 113)
				AND currency <> 20
				AND bettype = 29 
				AND betteam = N'1'

			INSERT INTO #rptWinloss
			(
				winlostdate,combo,sporttype
				,tickets_won,tickets_lose,stake_won,
				stake_lose,member_won,member_lose,
				ourPT_won,ourPT_lose,parlaytype
			)
			SELECT b.winlostdate, b.hdp2, b.transid2
				,SUM(CASE WHEN statusID = 112 THEN 1 ELSE 0 END) AS tickets_won
				,SUM(CASE WHEN statusID = 113 THEN 1 ELSE 0 END) AS tickets_lose
				,SUM(CASE WHEN statusID = 112 THEN stake * actualrate * (1 - tpositiontaking - CAST(ISNULL(epositiontaking, 0) AS DECIMAL(9,8))) ELSE 0 END) AS stake_won
				,SUM(CASE WHEN statusID = 113 THEN stake * actualrate * (1 - tpositiontaking - CAST(ISNULL(epositiontaking, 0) AS DECIMAL(9,8))) ELSE 0 END) AS stake_won
				,SUM(CASE WHEN statusID = 112 THEN -(winlost - actual_stake) * actualrate ELSE 0 END) AS member_won
				,SUM(CASE WHEN statusID = 113 THEN -(winlost - actual_stake) * actualrate ELSE 0 END) AS member_lose
				,SUM(CASE WHEN 1 - tpositiontaking = 0 THEN 0 ELSE CASE WHEN statusID = 112 THEN (-(winlost - actual_stake) * (1 - tpositiontaking - CAST(ISNULL(epositiontaking, 0) AS DECIMAL(9,8))) - scomm  + scomm * CAST(ISNULL(epositiontaking, 0) AS DECIMAL(9,8)) / (1 - tpositiontaking)) * actualrate ELSE 0 END END) AS ourPT_won
				,SUM(CASE WHEN 1 - tpositiontaking = 0 THEN 0 ELSE CASE WHEN statusID = 113 THEN (-(winlost - actual_stake) * (1 - tpositiontaking - CAST(ISNULL(epositiontaking, 0) AS DECIMAL(9,8))) - scomm  + scomm * CAST(ISNULL(epositiontaking, 0) AS DECIMAL(9,8)) / (1 - tpositiontaking)) * actualrate ELSE 0 END END) AS ourPT_lose
				,CASE WHEN b.bettype = 38 THEN 3
					  WHEN b.bettype = 376 THEN 4
					  WHEN b.bettype = 29 AND b.betteam = N'1' AND t.bac|16 = t.bac AND b.oddsspread = 2 THEN 77 --Parlay Generator & Boost
					  WHEN b.bettype = 29 AND b.betteam = N'1' AND b.oddsspread = 2 THEN 7
					  WHEN b.bettype = 29 AND b.betteam = N'1' AND t.bac|16 = t.bac THEN 6
					  WHEN b.bettype = 29 AND b.betteam = N'1' AND b.oddsspread = 1 THEN 5
					  WHEN b.bettype = 29 AND b.betteam = N'1' THEN 1
					  WHEN b.bettype = 29 AND b.betteam <> N'1' THEN 2
				END parlaytype
			FROM dbo.rmBettrans b WITH (NOLOCK)
				INNER JOIN #bettype bt ON b.bettype = bt.bettype
				INNER JOIN #tmpSelection s ON b.hdp2 = s.selection
				INNER JOIN #tmpSport sp ON b.transid2 = sp.sporttype
				LEFT JOIN #tmpBettrans t ON b.transid = t.transid
			WHERE winlostdate BETWEEN @f_date AND @t_date
				AND statusID IN (112, 113)
				AND b.currency <> 20
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
					)		
				AND (@Site = 2 OR
					EXISTS(SELECT 1 FROM bodb02.dbo.customer c WITH(NOLOCK) 
                                INNER JOIN bodb02.dbo.Site s (NOLOCK) ON c.site = s.site
                        WHERE c.custid = b.custid 
							AND CASE WHEN s.Site IN ('Saba789','NovaCasino','SEAL888') THEN 0 ELSE s.isDeposit END = @Site))						
				AND (CASE WHEN b.bettype = 29 THEN b.livehomescore ELSE b.liveindicator END = @LiveStatus OR @LiveStatus = 3)
			GROUP BY b.winlostdate, b.hdp2, b.transid2,
				CASE WHEN b.bettype = 38 THEN 3
					  WHEN b.bettype = 376 THEN 4
					  WHEN b.bettype = 29 AND b.betteam = N'1' AND t.bac|16 = t.bac AND b.oddsspread = 2 THEN 77
					  WHEN b.bettype = 29 AND b.betteam = N'1' AND b.oddsspread = 2 THEN 7
					  WHEN b.bettype = 29 AND b.betteam = N'1' AND t.bac|16 = t.bac THEN 6
					  WHEN b.bettype = 29 AND b.betteam = N'1' AND b.oddsspread = 1 THEN 5
					  WHEN b.bettype = 29 AND b.betteam = N'1' THEN 1
					  WHEN b.bettype = 29 AND b.betteam <> N'1' THEN 2
				END
			OPTION (RECOMPILE)

		END

		-- rmSumWinloss
		IF @FromDate <= @MoveBetsDay AND @ToDate >= @BalanceUpDay
		BEGIN
			SELECT	@f_date = CASE WHEN @FromDate < @BalanceUpDay THEN @BalanceUpDay ELSE @FromDate END
					,@t_date = CASE WHEN @ToDate > @MoveBetsDay THEN @MoveBetsDay ELSE @ToDate END

			INSERT INTO #rptWinloss
			(
				winlostdate,combo,sporttype
				,tickets_won,tickets_lose,stake_won,
				stake_lose,member_won,member_lose,
				ourPT_won,ourPT_lose,parlaytype
			)
			SELECT
				a.winlostdate, a.combo, a.sporttype
				,SUM(CASE WHEN statusID = 112 THEN betcount ELSE 0 END) AS tickets_won
				,SUM(CASE WHEN statusID = 113 THEN betcount ELSE 0 END) AS tickets_lose
				,SUM(CASE WHEN statusID = 112 THEN company_stake*actualrate - ISNULL(a.Extra_stake, 0) * actualrate ELSE 0 END) AS stake_won
				,SUM(CASE WHEN statusID = 113 THEN company_stake*actualrate - ISNULL(a.Extra_stake, 0) * actualrate ELSE 0 END) AS stake_lose
				,SUM(CASE WHEN statusID = 112 THEN -(a.winlost-a.stake)*actualrate ELSE 0 END) AS member_won
				,SUM(CASE WHEN statusID = 113 THEN -(a.winlost-a.stake)*actualrate ELSE 0 END) AS member_lose
				,SUM(CASE WHEN statusID = 112 THEN (company_winlost - ISNULL(a.Extra_winlost, 0) - ISNULL(a.scomm, 0) + ISNULL(a.Extra_comm, 0)) * actualrate ELSE 0 END) AS ourPT_won
				,SUM(CASE WHEN statusID = 113 THEN (company_winlost - ISNULL(a.Extra_winlost, 0) - ISNULL(a.scomm, 0) + ISNULL(a.Extra_comm, 0)) * actualrate ELSE 0 END) AS ourPT_lose		
				,a.parlaytype - 1
			FROM dbo.rmSumWinloss a WITH (NOLOCK)
			WHERE a.winlostdate BETWEEN @f_date AND @t_date				
				AND a.statusID IN (112, 113)
				AND a.currency <> 20
				AND EXISTS(SELECT TOP 1 1 FROM #ParlayType t WHERE a.parlaytype - 1 = t.ParlayType)
				AND EXISTS(SELECT 1 FROM #tmpSelection s WHERE a.combo = s.selection)
                AND EXISTS(SELECT 1 FROM #tmpSport sp WHERE a.sporttype = sp.sporttype)
                AND (@Site = 2 OR
					EXISTS(SELECT 1 FROM bodb02.dbo.customer c WITH(NOLOCK) 
                                INNER JOIN bodb02.dbo.Site s (NOLOCK) ON c.site = s.site
							WHERE c.custid = a.custid 
								AND CASE WHEN s.Site IN ('Saba789','NovaCasino','SEAL888') THEN 0 ELSE s.isDeposit END = @Site))
				AND (a.LiveIndicator = @LiveStatus OR @LiveStatus = 3)
			GROUP BY a.winlostdate, a.combo, a.sporttype,a.parlaytype - 1
			OPTION (RECOMPILE)

		END

		-- rmSumWinloss_Old
		IF @FromDate < @BalanceUpDay
		BEGIN
			SELECT	@f_date = @FromDate
					,@t_date = CASE WHEN @ToDate >= @BalanceUpDay THEN DATEADD(DAY, -1, @BalanceUpDay) ELSE @ToDate END

			INSERT INTO #rptWinloss
			(
				winlostdate,combo,sporttype
				,tickets_won,tickets_lose,stake_won,
				stake_lose,member_won,member_lose,
				ourPT_won,ourPT_lose,parlaytype
			)
			SELECT
				a.winlostdate, a.combo, a.sporttype
				,SUM(CASE WHEN statusID = 112 THEN betcount ELSE 0 END) AS tickets_won
				,SUM(CASE WHEN statusID = 113 THEN betcount ELSE 0 END) AS tickets_lose
				,SUM(CASE WHEN statusID = 112 THEN company_stake*actualrate - ISNULL(a.Extra_stake, 0) * actualrate ELSE 0 END) AS stake_won
				,SUM(CASE WHEN statusID = 113 THEN company_stake*actualrate - ISNULL(a.Extra_stake, 0) * actualrate ELSE 0 END) AS stake_lose
				,SUM(CASE WHEN statusID = 112 THEN -(a.winlost-a.stake)*actualrate ELSE 0 END) AS member_won
				,SUM(CASE WHEN statusID = 113 THEN -(a.winlost-a.stake)*actualrate ELSE 0 END) AS member_lose
				,SUM(CASE WHEN statusID = 112 THEN (company_winlost - ISNULL(a.Extra_winlost, 0) - ISNULL(a.scomm, 0) + ISNULL(a.Extra_comm, 0)) * actualrate ELSE 0 END) AS ourPT_won
				,SUM(CASE WHEN statusID = 113 THEN (company_winlost - ISNULL(a.Extra_winlost, 0) - ISNULL(a.scomm, 0) + ISNULL(a.Extra_comm, 0)) * actualrate ELSE 0 END) AS ourPT_lose		
				,a.parlaytype - 1
			FROM dbo.rmSumWinloss_Old a WITH (NOLOCK)
			WHERE a.winlostdate BETWEEN @f_date AND @t_date				
				AND a.statusID IN (112, 113)
				AND a.currency <> 20
				AND EXISTS(SELECT TOP 1 1 FROM #ParlayType t WHERE a.parlaytype - 1 = t.ParlayType)
				AND EXISTS(SELECT 1 FROM #tmpSelection s WHERE a.combo = s.selection)
                AND EXISTS(SELECT 1 FROM #tmpSport sp WHERE a.sporttype = sp.sporttype)
                AND (@Site = 2 OR
					EXISTS(SELECT 1 FROM bodb02.dbo.customer c WITH(NOLOCK) 
                                INNER JOIN bodb02.dbo.Site s (NOLOCK) ON c.site = s.site
							WHERE c.custid = a.custid 
								AND CASE WHEN s.Site IN ('Saba789','NovaCasino','SEAL888') THEN 0 ELSE s.isDeposit END = @Site))						
				AND (a.LiveIndicator = @LiveStatus OR @LiveStatus = 3)
			GROUP BY a.winlostdate, a.combo, a.sporttype,a.parlaytype - 1
			OPTION (RECOMPILE)

		END
	END

	-- Return data
	IF @ReportType = 1
		SELECT
			winlostdate
			,CASE WHEN combo > 10 THEN 10 ELSE combo END AS combo
			,SUM(tickets_won)	AS tickets_won
			,SUM(tickets_lose)	AS tickets_lose
			,SUM(stake_won)		AS stake_won
			,SUM(stake_lose)	AS stake_lose
			,SUM(member_won)	AS member_won
			,SUM(member_lose)	AS member_lose
			,SUM(ourPT_won)		AS ourPT_won
			,SUM(ourPT_lose)	AS ourPT_lose
		FROM #rptWinloss
		GROUP BY winlostdate, CASE WHEN combo > 10 THEN 10 ELSE combo END
		ORDER BY winlostdate ASC, combo ASC
	ELSE IF @ReportType = 2
		SELECT
			winlostdate
			,CASE WHEN sporttype NOT IN (-1,-3,1,2,3,4,5,6,7,8,9,11,43,44,-4,-5,50) THEN -2 ELSE sporttype END AS sporttype
			,SUM(tickets_won)	AS tickets_won
			,SUM(tickets_lose)	AS tickets_lose
			,SUM(stake_won)		AS stake_won
			,SUM(stake_lose)	AS stake_lose
			,SUM(member_won)	AS member_won
			,SUM(member_lose)	AS member_lose
			,SUM(ourPT_won)		AS ourPT_won
			,SUM(ourPT_lose)	AS ourPT_lose
		FROM #rptWinloss
		GROUP BY winlostdate, CASE WHEN sporttype NOT IN (-1,-3,1,2,3,4,5,6,7,8,9,11,43,44,-4,-5,50) THEN -2 ELSE sporttype END
		ORDER BY winlostdate ASC, sporttype ASC
	ELSE IF @ReportType = 3
		SELECT
			winlostdate
			,CASE WHEN parlaytype = 1 THEN 'Mix Parlay'
				WHEN parlaytype = 2 THEN 'Combo Parlay'
				WHEN parlaytype = 3 THEN 'Single Match Parlay'
				WHEN parlaytype = 4 THEN 'Penalty Shootout Combo'
				WHEN parlaytype = 5 THEN 'GOF'
				WHEN parlaytype = 6 THEN 'Parlay Generator'
				WHEN parlaytype = 7 THEN 'Parlay Boost'
				WHEN parlaytype = 77 THEN 'Parlay Boost & Generator'
				END AS parlaytype
			,SUM(tickets_won)	AS tickets_won
			,SUM(tickets_lose)	AS tickets_lose
			,SUM(stake_won)		AS stake_won
			,SUM(stake_lose)	AS stake_lose
			,SUM(member_won)	AS member_won
			,SUM(member_lose)	AS member_lose
			,SUM(ourPT_won)		AS ourPT_won
			,SUM(ourPT_lose)	AS ourPT_lose
		FROM #rptWinloss
		GROUP BY winlostdate, 
			CASE WHEN parlaytype = 1 THEN 'Mix Parlay'
				WHEN parlaytype = 2 THEN 'Combo Parlay'
				WHEN parlaytype = 3 THEN 'Single Match Parlay'
				WHEN parlaytype = 4 THEN 'Penalty Shootout Combo'
				WHEN parlaytype = 5 THEN 'GOF'
				WHEN parlaytype = 6 THEN 'Parlay Generator'
				WHEN parlaytype = 7 THEN 'Parlay Boost'
				WHEN parlaytype = 77 THEN 'Parlay Boost & Generator'
				END
		ORDER BY winlostdate ASC, 
			CASE WHEN parlaytype = 1 THEN 'Mix Parlay'
				WHEN parlaytype = 2 THEN 'Combo Parlay'
				WHEN parlaytype = 3 THEN 'Single Match Parlay'
				WHEN parlaytype = 4 THEN 'Penalty Shootout Combo'
				WHEN parlaytype = 5 THEN 'GOF'
				WHEN parlaytype = 6 THEN 'Parlay Generator'
				WHEN parlaytype = 7 THEN 'Parlay Boost'
				WHEN parlaytype = 77 THEN 'Parlay Boost & Generator'
				END ASC
	
	DROP TABLE #bettype
	DROP TABLE #rptWinloss
	DROP TABLE #tmpSelection
	DROP TABLE #tmpSport
	DROP TABLE #ParlayType
	DROP TABLE #tmpBettrans

END
GO