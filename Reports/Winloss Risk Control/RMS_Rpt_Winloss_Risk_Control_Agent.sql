/*<info serverAlias="DBRMS-bodb_RMS" executers="bodbRMSNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[RMS_Rpt_Winloss_Risk_Control_Agent]
	@fromdate		SMALLDATETIME,
	@todate			SMALLDATETIME,
	@custID			INT,
	@roleID			TINYINT,
	@ParlayType		VARCHAR(20) = '',
	@sporttype		VARCHAR(100) = '',
	@ReportBy		TINYINT = 1,
	@PageSize		INT = 0,
	@PageIndex		INT = 0,
	@TotalRecords   INT =0  OUTPUT,
	@Site			NVARCHAR(50) = ''
AS

/*
	Created: 20201030@Danny
	DB: DBRMS-bodb_RMS
	Task: report winloss risk control
		
	Revisions:	
		- 20201030@Danny: Initialize SP [RedmineID: #144471]		
		
	
	Parameter's Explanation:th
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

	IF (@custID = '' OR @custID IS NULL)
	RETURN


	-- Prepare data for filtering
	BEGIN
		-- Get MBU date
		create table #MBU (
		balanceUpday	DATETIME ,
		movebetsday		DATETIME
		)
		insert into #MBU  exec RMS_SelBalanceUpDay

		select @movebetsday = movebetsday, @balanceUpday = balanceUpday FROM #MBU

		-- Get custid list following site (get super if credit site, get agent if deposit site)
		CREATE TABLE #CustList (custID INT)
		IF @roleID = 4 
		BEGIN
			INSERT INTO #CustList(custID)
			SELECT custid 
			FROM bodb02.dbo.Customer WITH(NOLOCK)
			WHERE srecommend = @custID and roleid = 1 and site = @Site
		END

		IF @roleID = 3 
		BEGIN
			INSERT INTO #CustList(custID)
			SELECT custid 
			FROM bodb02.dbo.Customer WITH(NOLOCK)
			WHERE mrecommend = @custID and roleid = 1 and site = @Site
		END

		IF @roleID = 2 
		BEGIN
			INSERT INTO #CustList(custID)
			SELECT custid 
			FROM bodb02.dbo.Customer WITH(NOLOCK)
			WHERE recommend = @custID and roleid = 1 and site = @Site
		END
	
		CREATE TABLE #tmpSport (sporttype INT)
		INSERT INTO #tmpSport (sporttype)
		SELECT val FROM dbo.f_RMS_strSplit(@sporttype, ',')

		-- Get Sport
		IF ',' + @sporttype + ',' LIKE '%,-2,%'
			INSERT INTO #tmpSport (sporttype)
			SELECT SportType FROM bodb02.dbo.Sports WITH (NOLOCK)
			WHERE SportType NOT IN (1,2,3,4,5,6,7,8,9,11,43,44)
				AND SportType <= 99

		CREATE TABLE #tmpSelection (selection INT)
		DECLARE @selection NVARCHAR(4000) = '2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,64,65,66,67,68,69,70,71,72,73,74,75,76,77,78,79,80,81,82,83,84,85,86,87,88,89,90,91,92,93,94,95,96,97,98,99,100'
		-- all selections (2 --> 100)
		INSERT INTO #tmpSelection (selection)
		SELECT val FROM dbo.f_RMS_strSplit(@selection, ',')

		-- Get bettype
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
			BetCount INT
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
			INNER JOIN #CustList c ON c.custID = b.custid
			INNER JOIN #tmpSelection s ON b.hdp2 = s.selection
			WHERE b.winlostdate BETWEEN @f_date AND @t_date
				AND statusID IN (111,112, 113)
				AND b.currency <> 20
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
				(winlost - actual_stake) * actualrate, --member_Winloss
				(awinlost + mwinlost + swinlost)  * actualrate, --SMA_winloss
				-(ISNULL(extra_Winlost,0)  * actualrate + ISNULL(Extra_comm,0) * actualrate)  ,  --ExtraPT
				-(scomm * actualrate), --Commission
				(company_winlost - ISNULL(b.Extra_winlost, 0) - ISNULL(b.scomm, 0) + ISNULL(b.Extra_comm, 0)) * actualrate , --RealIncome
				(company_stake - ISNULL(Extra_stake,0))* actualrate, -- Real turnover
				b.betcount
			
			FROM  dbo.rmSumWinloss b WITH (NOLOCK)
			INNER JOIN #tmpSport sp ON b.sporttype = sp.sporttype
			INNER JOIN #CustList c ON c.custID = b.custid
			INNER JOIN #tmpSelection s ON b.combo = s.selection
			WHERE b.winlostdate BETWEEN @f_date AND @t_date
				AND statusID IN (111,112, 113)
				AND b.currency <> 20
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
				(winlost - actual_stake ) * actualrate, --member_Winloss
				(awinlost + mwinlost + swinlost)  * actualrate, --SMA_winloss
				-(ISNULL(extra_Winlost,0)  * actualrate + ISNULL(Extra_comm,0) * actualrate)  ,  --ExtraPT
				-(scomm * actualrate), --Commission
				(company_winlost - ISNULL(b.Extra_winlost, 0) - ISNULL(b.scomm, 0) + ISNULL(b.Extra_comm, 0)) * actualrate , --RealIncome
				(company_stake - ISNULL(Extra_stake,0))* actualrate, -- Real turnover
				b.betcount
			
			FROM  dbo.rmSumWinloss_Old b WITH (NOLOCK)
			INNER JOIN #tmpSport sp ON b.sporttype = sp.sporttype
			INNER JOIN #CustList c ON c.custID = b.custid
			INNER JOIN #tmpSelection s ON b.combo = s.selection
			WHERE b.winlostdate BETWEEN @f_date AND @t_date
				AND statusID IN (111,112, 113)
				AND b.currency <> 20
				AND ',' + @ParlayType + ',' LIKE '%,' + CONVERT(VARCHAR(5), b.ParlayType - 1) + ',%'
		END

	
	END

	IF @roleID = 4
	BEGIN
		INSERT INTO #rptRiskWLControl_Summary(
					CustID,
					UserName, 
					RoleID, NoMember, BetCount, MemberWinloss, SMAwinloss, ExtraPT, Commission, RealIncome, RealTurnover)
		SELECT		
					b.mrecommend,
					c.UserName,
					c.RoleID,
					COUNT(distinct b.custid) noMember,
					SUM(betCount)  betCount,
					SUM(member_Winloss) member_Winloss,
					SUM(SMA_winloss) SMA_winloss ,
					SUM(ExtraPT)  ExtraPT,
					SUM(Commission)  Commission,
					SUM(RealIncome) RealIncome ,
					SUM(RealTurnover) RealTurnover 
		FROM		#rptRiskWLControl b
		INNER JOIN	bodb02.dbo.custInfo c ON c.custid = b.mrecommend
		GROUP BY	b.mrecommend,c.UserName,c.RoleID

	END


	IF @roleID = 3
	BEGIN
		INSERT INTO #rptRiskWLControl_Summary(
					CustID,
					UserName, 
					RoleID, NoMember, BetCount, MemberWinloss, SMAwinloss, ExtraPT, Commission, RealIncome, RealTurnover)
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
					SUM(RealTurnover) RealTurnover 
		FROM		#rptRiskWLControl b
		INNER JOIN	bodb02.dbo.custInfo c ON c.custid = b.recommend
		GROUP BY	b.recommend,c.UserName,c.RoleID

	END

	IF @roleID = 2
	BEGIN
		INSERT INTO #rptRiskWLControl_Summary(
					CustID,
					UserName, 
					RoleID, NoMember, BetCount, MemberWinloss, SMAwinloss, ExtraPT, Commission, RealIncome, RealTurnover)
		SELECT		
					b.CustID,
					c.UserName,
					c.RoleID,
					0 noMember,
					SUM(betCount)  betCount,
					SUM(member_Winloss) member_Winloss,
					SUM(SMA_winloss) SMA_winloss ,
					SUM(ExtraPT)  ExtraPT,
					SUM(Commission)  Commission,
					SUM(RealIncome) RealIncome ,
					SUM(RealTurnover) RealTurnover 
		FROM		#rptRiskWLControl b
		INNER JOIN	bodb02.dbo.custInfo c ON c.custid = b.CustID
		GROUP BY	b.CustID,c.UserName,c.RoleID

		IF @PageSize <=0 AND @PageIndex <=0 
		BEGIN
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
				RealTurnover
			FROM #rptRiskWLControl_Summary
			ORDER BY UserName

			RETURN
		END

		IF @TotalRecords = 0  
		BEGIN  
			SELECT @TotalRecords = COUNT(CustID)
			FROM #rptRiskWLControl_Summary
		END

		DECLARE @RowStart	INT,
				@RowEnd		INT
		
		SELECT	@PageIndex = @PageIndex - 1,
				@RowStart = @PageSize * @PageIndex + 1,
				@RowEnd = @RowStart + @PageSize - 1;

		SELECT wl.*
		FROM (
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
					ROW_NUMBER() over(order by UserName) as RowNum,
					@Site as Site
				FROM #rptRiskWLControl_Summary
		) wl
		WHERE wl.RowNum BETWEEN @RowStart AND @RowEnd;

		SELECT @TotalRecords as TotalRecords;

		RETURN
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
			@Site as Site
	FROM #rptRiskWLControl_Summary
	ORDER BY UserName
	
	DROP TABLE #CustList
	DROP TABLE #MBU
	DROP TABLE #bettype
	DROP TABLE #rptRiskWLControl_Summary
	DROP TABLE #rptRiskWLControl
	DROP TABLE #tmpSport
	DROP TABLE #tmpSelection
END
GO

