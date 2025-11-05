/*<info serverAlias="DBRMS-bodb_RMS" executers="wsv_rms" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[RMS_Rpt_Winloss_Risk_Control]
	@fromdate		SMALLDATETIME,
	@todate			SMALLDATETIME,
	@company		VARCHAR(MAX) = '', -- '' Get All Company else get exactly company
	@ParlayType		VARCHAR(100) = '',
	@sporttype		VARCHAR(100) = '',
	@ReportBy		TINYINT = 1,
	@Selection		VARCHAR(MAX) = '',
	@LiveStatus		TINYINT = 3
AS

/*
	Created: 20201030@Danny
	DB: DBRMS-bodb_RMS
	Task: report winloss risk control
		
	Revisions:	
		- 20201030@Danny: Initialize SP [RedmineID: #144471]		
		- 20220301@Danny: Add filter by combo [RedmineID: #169072]
		- 20220519@Danny: add filter by Live Status [RedmineID: #172691]
		- 20231020@Cherry: Parlay Generator (#195498)
		- 20231201@Cherry: Parlay Type for Parlay Boost (#197680)
		- 20240115@Cherry: Change attribute for Parlay Generator (#199766)
		- 20240312@Cherry: Change SQL account in metadata (#202012)
		- 20241212@Cherry: Separate Cricket (#214664)
		- 20251016@Cherry: Move sites NovaCasino, SEAL888 from Deposit to Credit (#241763)
		- 20251020@Cherry: Integrate Hybrid Parlay (#242165)
	
	Parameter's Explanation:
		- @sporttype:
					. '1': soccer only
					. '-1': Combined other sports
					. '-2': Other sports
					. '-3': Combined sports

		- @ParlayType:
					. 1: Mix parlay
					. 2: Combo parlay
					. 3: Single Match Parlay
					. 4: Panalty shootout combo
					. 5: GOF
					. 6: Parlay Generator
					. 7: Parlay Boost
					. 8: Hybrid Parlay

		- @ReportBy:
					. '1': Company
					. '2': Daily
					. '3': Monthly
					. '4': Parlay Type
					. '5': TOP 20

*/

BEGIN
	SET NOCOUNT ON

	DECLARE @movebetsday	DATETIME
	DECLARE @balanceUpday	DATETIME 

	create table #MBU (
	balanceUpday	DATETIME ,
	movebetsday	DATETIME
	)
	insert into #MBU (balanceUpday,movebetsday)
	exec bodb02.dbo.Age_SelBalanceUpDay

	select @movebetsday = movebetsday, @balanceUpday = balanceUpday FROM #MBU

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
		
		IF ',' + @ParlayType + ',' LIKE '%,1,%' OR ',' + @ParlayType + ',' LIKE '%,2,%' OR ',' + @ParlayType + ',' LIKE '%,5,%' OR ',' + @ParlayType + ',' LIKE '%,6,%' OR ',' + @ParlayType + ',' LIKE '%,7,%' OR ',' + @ParlayType + ',' LIKE '%,8,%'
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


		CREATE TABLE #rptRiskWLControl
		(
			CustID int,
			recommend int,
			mrecommend int,
			srecommend int,
			member_Winloss money,
			SMA_winloss money,
			ExtraPT money,
			Commission money,
			RealIncome money,
			RealTurnover money,
			betCount INT
		)

		CREATE TABLE #rptRiskWLControl_Summary
		(
			Site		NVARCHAR(50),
			IsDeposit	 BIT,
			NoMember	INT,
			MemberWinloss money,
			SMAwinloss money,
			ExtraPT money,
			Commission money,
			RealIncome money,
			RealTurnover money,
			BetCount INT
		)

		CREATE TABLE #tmpBettrans
		(
			transid BIGINT,
			bac INT
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
				AND statusID IN (111, 112, 113)
				AND currency <> 20
				AND bettype = 29 
				AND betteam = N'1'

			INSERT INTO #rptRiskWLControl 
			(
				CustID ,
				recommend ,
				mrecommend,
				srecommend,
				member_Winloss ,
				SMA_winloss ,
				ExtraPT ,
				Commission ,
				RealIncome ,
				RealTurnover,
				betCount
			)

			SELECT	
				b.custid,
				b.recommend,
				b.mrecommend,
				b.srecommend,
				(winlost - actual_stake) * actualrate,
				(awinlost + mwinlost + swinlost)  * actualrate,
				-((winlost - actual_stake + CASE WHEN tpositiontaking = 1 THEN 0  ELSE scomm / (1 - tpositiontaking) END) * CAST(ISNULL(b.epositiontaking, 0) AS DECIMAL(9,8)) * actualrate),
				-(scomm * actualrate),
				-(winlost - actual_stake + awinlost + mwinlost + swinlost)* actualrate - scomm * actualrate + ((winlost - actual_stake + CASE WHEN tpositiontaking = 1 THEN 0  ELSE scomm / (1 - tpositiontaking) END) * CAST(ISNULL(b.epositiontaking, 0) AS DECIMAL(9,8)) * actualrate),
				((CASE WHEN b.statusID IN (103) THEN 0   WHEN b.tpositiontaking = 1 THEN 0  ELSE (1- b.tpositiontaking - CAST(ISNULL(b.epositiontaking, 0) AS DECIMAL(9,8))) * b.stake END) * actualrate) ,
				1
			FROM  dbo.rmBettrans b WITH (NOLOCK)
				INNER JOIN #bettype bt ON b.bettype = bt.bettype
				INNER JOIN #tmpSport sp ON b.transid2 = sp.sporttype
				INNER JOIN #tmpSelection s ON b.hdp2 = s.selection
				LEFT JOIN #tmpBettrans t ON b.transid = t.transid
			WHERE b.winlostdate BETWEEN @f_date AND @t_date
				AND statusID IN (111,112, 113)
				AND b.currency <> 20
				AND (b.bettype <> 29
					OR (EXISTS(SELECT TOP 1 1 FROM #ParlayType WHERE ParlayType = 1)
						AND b.bettype = 29 AND b.betteam = N'1' AND ISNULL(b.oddsspread,0) <> 3)
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
				AND (CASE WHEN b.bettype = 29 THEN b.livehomescore ELSE b.liveindicator END = @LiveStatus OR @LiveStatus = 3)
		END

		-- rmSumWinloss
		IF @FromDate <= @MoveBetsDay AND @ToDate >= @BalanceUpDay
		BEGIN
			SELECT	@f_date = CASE WHEN @FromDate < @BalanceUpDay THEN @BalanceUpDay ELSE @FromDate END
					,@t_date = CASE WHEN @ToDate > @MoveBetsDay THEN @MoveBetsDay ELSE @ToDate END
			

			INSERT INTO #rptRiskWLControl 
			(
				CustID ,
				recommend ,
				mrecommend,
				srecommend,
				member_Winloss,
				SMA_winloss ,
				ExtraPT ,
				Commission ,
				RealIncome ,
				RealTurnover,
				betCount
			)

			SELECT	
				b.custid,
				b.recommend,
				b.mrecommend,
				b.srecommend,
				(winlost - actual_stake) * actualrate, --member_Winloss
				(awinlost + mwinlost + swinlost)  * actualrate, --SMA_winloss
				-(ISNULL(extra_Winlost,0)  * actualrate + ISNULL(Extra_comm,0) * actualrate)  ,  --ExtraPT
				-(scomm * actualrate), --Commission
				--company_winlost * actualrate -  scomm * actualrate + (ISNULL(extra_Winlost,0)  * actualrate + ISNULL(Extra_comm,0) * actualrate), --RealIncome
				(company_winlost - ISNULL(b.Extra_winlost, 0) - ISNULL(b.scomm, 0) + ISNULL(b.Extra_comm, 0)) * actualrate ,  --RealIncome
				(company_stake - ISNULL(Extra_stake,0))* actualrate, -- Real turnover
				b.betcount
			
			FROM  dbo.rmSumWinloss b WITH (NOLOCK)
			INNER JOIN #tmpSport sp ON b.sporttype = sp.sporttype
			INNER JOIN #tmpSelection s ON b.combo = s.selection
			WHERE b.winlostdate BETWEEN @f_date AND @t_date
				AND statusID IN (111,112, 113)
				AND b.currency <> 20
				AND EXISTS(SELECT TOP 1 1 FROM #ParlayType t WHERE b.parlaytype - 1 = t.ParlayType)
				AND (b.LiveIndicator = @LiveStatus OR @LiveStatus = 3)

		END

		-- rmSumWinloss_Old
		IF @FromDate < @BalanceUpDay
		BEGIN
			SELECT	@f_date = @FromDate
					,@t_date = CASE WHEN @ToDate >= @BalanceUpDay THEN DATEADD(DAY, -1, @BalanceUpDay) ELSE @ToDate END
			
			INSERT INTO #rptRiskWLControl 
			(
				CustID ,
				recommend ,
				mrecommend,
				srecommend,
				member_Winloss,
				SMA_winloss ,
				ExtraPT ,
				Commission ,
				RealIncome ,
				RealTurnover ,
				betCount
			)

			SELECT	
				b.custid,
				b.recommend,
				b.mrecommend,
				b.srecommend,
				(winlost - actual_stake) * actualrate, --member_Winloss
				(awinlost + mwinlost + swinlost)  * actualrate, --SMA_winloss
				-(ISNULL(extra_Winlost,0)  * actualrate + ISNULL(Extra_comm,0) * actualrate)  ,  --ExtraPT
				-(scomm * actualrate), --Commission
				(company_winlost - ISNULL(b.Extra_winlost, 0) - ISNULL(b.scomm, 0) + ISNULL(b.Extra_comm, 0)) * actualrate , --RealIncome
				(company_stake - ISNULL(Extra_stake,0))* actualrate, -- Real turnover
				b.betcount
			
			FROM  dbo.rmSumWinloss_Old b WITH (NOLOCK)
			INNER JOIN #tmpSport sp ON b.sporttype = sp.sporttype
			INNER JOIN #tmpSelection s ON b.combo = s.selection
			WHERE b.winlostdate BETWEEN @f_date AND @t_date
				AND statusID IN (111,112, 113)
				AND b.currency <> 20
				AND EXISTS(SELECT TOP 1 1 FROM #ParlayType t WHERE b.parlaytype - 1 = t.ParlayType)
				AND (b.LiveIndicator = @LiveStatus OR @LiveStatus = 3)
		END


		INSERT INTO #rptRiskWLControl_Summary(Site, IsDeposit, NoMember, BetCount, MemberWinloss, SMAwinloss, ExtraPT, Commission, RealIncome, RealTurnover)
			SELECT		s.site,
						CASE WHEN s.site IN ('Saba789','NovaCasino','SEAL888') THEN 0 ELSE s.isDeposit END,
						COUNT(distinct b.custid) noMember,
						SUM(betCount)  betCount,
						SUM(member_Winloss) member_Winloss,
						SUM(SMA_winloss) SMA_winloss ,
						SUM(ExtraPT)  ExtraPT,
						SUM(Commission)  Commission,
						SUM(RealIncome) RealIncome ,
						SUM(RealTurnover) RealTurnover 
			FROM #rptRiskWLControl b
			INNER JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON b.CustID = c.custid
			INNER JOIN bodb02.dbo.Site s  WITH(NOLOCK) ON  c.site = s.site
			GROUP BY s.site, CASE WHEN s.site IN ('Saba789','NovaCasino','SEAL888') THEN 0 ELSE s.isDeposit END

	
	END
		
	CREATE TABLE #company(Site NVARCHAR(50))

	INSERT INTO #company(Site)
	select value from  STRING_SPLIT(@company, ',')

	select	t.Site as  Username, 
			t.IsDeposit, 
			t.NoMember, 
			t.BetCount, 
			t.MemberWinloss, 
			t.SMAwinloss, 
			t.ExtraPT, 
			t.Commission, 
			t.RealIncome, 
			t.RealTurnover
	FROM #rptRiskWLControl_Summary t
	INNER JOIN #company c ON t.Site = c.Site
	ORDER BY t. IsDeposit ASC

	DROP TABLE #company
	DROP TABLE #MBU
	DROP TABLE #bettype
	DROP TABLE #rptRiskWLControl_Summary
	DROP TABLE #rptRiskWLControl
	DROP TABLE #tmpSport
	DROP TABLE #tmpSelection
	DROP TABLE #ParlayType
	DROP TABLE #tmpBettrans
END
GO

