/*<info serverAlias="DBRMS-bodb_RMS" executers="bodbRMSNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[RMS_Rpt_Winloss_Risk_Control_Company]
	@fromdate		SMALLDATETIME,
	@todate			SMALLDATETIME,
	@company		NVARCHAR(50),
	@isDeposit		BIT,
	@ParlayType		VARCHAR(20) = '',
	@sporttype		VARCHAR(100) = '',
	@ReportBy	TINYINT = 1
AS

/*
	Created: 20201030@Danny
	DB: DBRMS-bodb_RMS
	Task: report winloss risk control
		
	Revisions:	
		- 20201030@Danny: Initialize SP [RedmineID: #144471]		
		
	
	Parameter's Explanation:
		- @company  :  Only Site
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
	DECLARE @f_date SMALLDATETIME, @t_date SMALLDATETIME

	IF (@company = '' OR @company IS NULL)
	RETURN


	-- Prepare data for filtering
	BEGIN
		-- Get MBU date
		create table #MBU (
		balanceUpday	DATETIME ,
		movebetsday	DATETIME
		)
		insert into #MBU  exec RMS_SelBalanceUpDay

		select @movebetsday = movebetsday, @balanceUpday = balanceUpday FROM #MBU

		-- Get custid list following site (get super if credit site, get agent if deposit site)
		CREATE TABLE #CustList (custID INT)
		INSERT INTO #CustList(custID)
		SELECT custid 
		FROM bodb02.dbo.Customer WITH(NOLOCK)
		WHERE Site = @company and roleid = 2
	


		
		CREATE TABLE #tmpSport (sporttype INT)
		INSERT INTO #tmpSport (sporttype)
		SELECT val FROM dbo.f_RMS_strSplit(@sporttype, ',')


		-- Get Sport
		IF ',' + @sporttype + ',' LIKE '%,-2,%'
			INSERT INTO #tmpSport (sporttype)
			SELECT SportType FROM bodb02.dbo.Sports WITH (NOLOCK)
			WHERE SportType NOT IN (1,2,3,4,5,6,7,8,9,11,43,44)
				AND SportType <= 99

		
		-- Get bettype
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

	END

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
			CustID		INT,
			UserName	NVARCHAR(50),
			RoleID		TINYINT,
			NoMember	INT,
			MemberWinloss money,
			SMAwinloss money,
			ExtraPT money,
			Commission money,
			RealIncome money,
			RealTurnover money,
			BetCount INT,
			Margin smallmoney
		)

	-- get data Credit
	BEGIN
		-- rmBettrans
		IF @ToDate > @MoveBetsDay
		BEGIN
			SELECT	@f_date = CASE WHEN @FromDate <= @MoveBetsDay THEN DATEADD(DAY, 1, @MoveBetsDay) ELSE @FromDate END
					,@t_date = @ToDate

			INSERT INTO #rptRiskWLControl 
			(
				CustID ,
				recommend,
				mrecommend ,
				srecommend ,
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
				b.mrecommend ,
				b.srecommend ,
				(winlost - actual_stake + playercomm) * actualrate,
				(awinlost + comm - playercomm + mwinlost + acomm - comm + swinlost + scomm - acomm)  * actualrate,
				-((winlost - actual_stake + CASE WHEN tpositiontaking = 1 THEN 0  ELSE scomm / (1 - tpositiontaking) END) * CAST(ISNULL(b.epositiontaking, 0) AS DECIMAL(9,8)) * actualrate),
				-(scomm * actualrate),
				-(winlost - actual_stake + awinlost + mwinlost + swinlost)* actualrate - scomm * actualrate - ((winlost - actual_stake + CASE WHEN tpositiontaking = 1 THEN 0  ELSE scomm / (1 - tpositiontaking) END) * CAST(ISNULL(b.epositiontaking, 0) AS DECIMAL(9,8)) * actualrate),
				((CASE WHEN b.statusID IN (103) THEN 0   WHEN b.tpositiontaking = 1 THEN 0  ELSE (1- b.tpositiontaking - CAST(ISNULL(b.epositiontaking, 0) AS DECIMAL(9,8))) * b.stake END) * actualrate) ,
				1
			FROM  rmBettrans b WITH (NOLOCK)
			INNER JOIN #bettype bt ON b.bettype = bt.bettype
			INNER JOIN #tmpSport sp ON b.transid2 = sp.sporttype
			INNER JOIN #CustList c ON c.custID = b.recommend
			WHERE b.winlostdate BETWEEN @f_date AND @t_date
				AND statusID IN (111,112, 113)
				AND 1 = CASE
							WHEN b.bettype = 29 AND @ComboType IN (1, 2) THEN CASE
								WHEN @ComboType = 1 AND b.betteam = N'1' THEN 1
								WHEN @ComboType = 2 AND b.betteam <> N'1' THEN 1
								ELSE 0 END
							ELSE 1 END
		END

		-- rmSumWinloss
		IF @FromDate <= @MoveBetsDay AND @ToDate >= @BalanceUpDay
		BEGIN
			SELECT	@f_date = CASE WHEN @FromDate < @BalanceUpDay THEN @BalanceUpDay ELSE @FromDate END
					,@t_date = CASE WHEN @ToDate > @MoveBetsDay THEN @MoveBetsDay ELSE @ToDate END
			

			INSERT INTO #rptRiskWLControl 
			(
				CustID ,
				recommend,
				mrecommend ,
				srecommend ,
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
				b.mrecommend ,
				b.srecommend ,
				(winlost - actual_stake + playercomm) * actualrate, --member_Winloss
				(awinlost + comm - playercomm + mwinlost + acomm - comm + swinlost + scomm - acomm)  * actualrate, --SMA_winloss
				-(ISNULL(extra_Winlost,0)  * actualrate + ISNULL(Extra_comm,0) * actualrate)  ,  --ExtraPT
				-(scomm * actualrate), --Commission
				company_winlost * actualrate -  scomm * actualrate - (ISNULL(extra_Winlost,0)  * actualrate + ISNULL(Extra_comm,0) * actualrate), --RealIncome
				(company_stake - ISNULL(Extra_stake,0))* actualrate, -- Real turnover
				b.betcount
			
			FROM  dbo.rmSumWinloss b WITH (NOLOCK)
			INNER JOIN #tmpSport sp ON b.sporttype = sp.sporttype
			INNER JOIN #CustList c ON c.custID = b.recommend
			WHERE b.winlostdate BETWEEN @f_date AND @t_date
				AND statusID IN (111,112, 113)
				AND ',' + @ParlayType + ',' LIKE '%,' + CONVERT(VARCHAR(5), b.ParlayType - 1) + ',%'

		END

		-- rmSumWinloss_Old
		IF @FromDate < @BalanceUpDay
		BEGIN
			SELECT	@f_date = @FromDate
					,@t_date = CASE WHEN @ToDate >= @BalanceUpDay THEN DATEADD(DAY, -1, @BalanceUpDay) ELSE @ToDate END
			
			INSERT INTO #rptRiskWLControl 
			(
				CustID ,
				recommend,
				mrecommend ,
				srecommend ,
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
				b.mrecommend ,
				b.srecommend ,
				(winlost - actual_stake + playercomm) * actualrate, --member_Winloss
				(awinlost + comm - playercomm + mwinlost + acomm - comm + swinlost + scomm - acomm)  * actualrate, --SMA_winloss
				-(ISNULL(extra_Winlost,0)  * actualrate + ISNULL(Extra_comm,0) * actualrate)  ,  --ExtraPT
				-(scomm * actualrate), --Commission
				company_winlost * actualrate -  scomm * actualrate - (ISNULL(extra_Winlost,0)  * actualrate + ISNULL(Extra_comm,0) * actualrate), --RealIncome
				(company_stake - ISNULL(Extra_stake,0))* actualrate, -- Real turnover
				b.betcount
			
			FROM  dbo.rmSumWinloss_Old b WITH (NOLOCK)
			INNER JOIN #tmpSport sp ON b.sporttype = sp.sporttype
			INNER JOIN #CustList c ON c.custID = b.recommend
			WHERE b.winlostdate BETWEEN @f_date AND @t_date
				AND statusID IN (111,112, 113)
				AND ',' + @ParlayType + ',' LIKE '%,' + CONVERT(VARCHAR(5), b.ParlayType - 1) + ',%'
		END

	
	END

	IF @isDeposit = 0 
	BEGIN
		INSERT INTO #rptRiskWLControl_Summary(
					CustID,
					UserName, 
					RoleID, NoMember, BetCount, MemberWinloss, SMAwinloss, ExtraPT, Commission, RealIncome, RealTurnover, Margin)
		SELECT		
					b.srecommend,
					c.UserName,
					c.RoleID,
					COUNT(distinct b.custid) noMember,
					SUM(betCount)  betCount,
					SUM(member_Winloss) member_Winloss,
					SUM(SMA_winloss) SMA_winloss ,
					SUM(ExtraPT)  ExtraPT,
					SUM(Commission)  Commission,
					SUM(RealIncome) RealIncome ,
					SUM(RealTurnover) RealTurnover ,
					CASE WHEN ISNULL(SUM(RealTurnover),0) = 0 THEN 0. ELSE SUM(RealIncome)/ SUM(RealTurnover) * 100 END as Margin
		FROM		#rptRiskWLControl b
		INNER JOIN	bodb02.dbo.custInfo c ON c.custid = b.srecommend
		GROUP BY	b.srecommend,c.UserName,c.RoleID

	END

	IF @isDeposit = 1
	BEGIN
		INSERT INTO #rptRiskWLControl_Summary(
				CustID,
				UserName, 
				RoleID, NoMember, BetCount, MemberWinloss, SMAwinloss, ExtraPT, Commission, RealIncome, RealTurnover, Margin)
		SELECT		
					b.recommend,
					c.UserName,
					c.RoleID,
					COUNT(distinct b.custid) noMember,
					SUM(betCount)  betCount,
					SUM(member_Winloss) member_Winloss,
					SUM(SMA_winloss) SMA_winloss ,
					SUM(ExtraPT)  ExtraPT,
					SUM(Commission)  Commission,
					SUM(RealIncome) RealIncome ,
					SUM(RealTurnover) RealTurnover ,
					CASE WHEN ISNULL(SUM(RealTurnover),0) = 0 THEN 0. ELSE SUM(RealIncome)/ SUM(RealTurnover) * 100 END as Margin
		FROM	#rptRiskWLControl b
		INNER JOIN	bodb02.dbo.custInfo c ON c.custid = b.recommend
		GROUP BY	b.recommend,c.UserName,c.RoleID

	END

	SELECT	CustID,
			UserName,
			RoleID, 
			NoMember, 
			BetCount, 
			MemberWinloss, 
			SMAwinloss, 
			ExtraPT, 
			Commission, 
			RealIncome, 
			RealTurnover, 
			Margin
	FROM #rptRiskWLControl_Summary
	ORDER BY UserName
	
	DROP TABLE #CustList
	DROP TABLE #MBU
	DROP TABLE #bettype
	DROP TABLE #rptRiskWLControl_Summary
	DROP TABLE #rptRiskWLControl
	DROP TABLE #tmpSport
END
GO

