/*<info serverAlias="DBRMS-bodb_RMS" executers="bodbRMSNet" viewers="" isFunction="0" isNested="0"></info>*/

  ALTER PROCEDURE [dbo].[RMS_Rpt_ComboParlay_Winloss_Ag]
	@custid		INT,
	@fromdate	DATETIME,
	@todate		DATETIME,
	@movebetsday DATETIME,
	@balanceUpday DATETIME = NULL,
	@sporttype VARCHAR(100)='',
	@selection	VARCHAR(100) = '',
	@ParlayType	VARCHAR(10)=''
	
AS
	/*
		Created: Winnie	
		Date: 20160511
		DB: DBRMS/bodb_RMS
		Task: Get report win loss for downlines by specific Agent
		
		Revisions:		
		- 20170719@Winnie: Add MuayThai RedmineID: #79500	
		- 20180927@Jacob: Apply Extra PT and Super Comm to Report.  RedmineID: #100951 	
		- 20190214@Jacob: Add Bet Builder RedmineID: #108694			
		Parameter's Explanation:
			- @sporttype = '1' : soccer only
						= '2' : Other sports
						= '3' : combined sports
			- @ParlayType = 1: Mix parlay
							2: Combo parlay
							3: Single Match Parlay
	*/ 
SET NOCOUNT ON
	DECLARE @f_date DATETIME,
			@t_date DATETIME
	
	DECLARE @tmpSum TABLE (
		month VARCHAR(7)
		,username varchar(50)
		,tickets_won INT
		,tickets_lose INT
		,stake_won MONEY
		,stake_lose MONEY
		,member_won MONEY
		,member_lose MONEY
		,ourPT_won MONEY
		,ourPT_lose MONEY
	)			
	
	
	DECLARE @tmpSelection TABLE(selection tinyint)
	DECLARE @10UP VARCHAR(500),@all varchar(500)
	
	DECLARE @tmpSport TABLE (sporttype int)
	
	
	INSERT INTO @tmpSport (sporttype)
	SELECT val
	FROM f_RMS_strSplit (@sporttype,',')
	IF EXISTS (SELECT TOP 1 1 FROM @tmpSport WHERE sporttype=-2)
	BEGIN
	INSERT INTO @tmpSport
	SELECT SportType FROM bodb02.dbo.Sports(NOLOCK) WHERE SportType NOT IN (1,2,3,4,5,6,7,8,9,11,43,44)
	END

	DECLARE @IsMixParlay BIT = 0, @IsComboParlay BIT = 0, @IsSingleMatchParlay BIT = 0
	SELECT  @IsMixParlay = CASE WHEN CHARINDEX('1', @ParlayType) > 0 THEN 1 ELSE 0 END,
		   @IsComboParlay = CASE WHEN CHARINDEX('2', @ParlayType) > 0 THEN 1 ELSE 0 END,
		   @IsSingleMatchParlay = CASE WHEN CHARINDEX('3', @ParlayType) > 0 THEN 1 ELSE 0 END
	
	INSERT INTO @tmpSelection
	SELECT val
	FROM f_RMS_strSplit (@selection,',')
	
	--Check selection is 10-UP
	IF EXISTS(SELECT TOP 1 1 FROM @tmpSelection WHERE selection = 0)
	BEGIN
		SELECT @all = '2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,64,65,66,67,68,69,70,71,72,73,74,75,76,77,78,79,80,81,82,83,84,85,86,87,88,89,90,91,92,93,94,95,96,97,98,99,100'
		DELETE FROM @tmpSelection
		INSERT INTO @tmpSelection
		SELECT val
		FROM f_RMS_strSplit (@all,',')		
	END
	ELSE IF EXISTS(SELECT TOP 1 1 FROM @tmpSelection WHERE selection = 10)
	BEGIN
		SELECT @10up = '11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,64,65,66,67,68,69,70,71,72,73,74,75,76,77,78,79,80,81,82,83,84,85,86,87,88,89,90,91,92,93,94,95,96,97,98,99,100'

		INSERT INTO @tmpSelection
		SELECT val
		FROM f_RMS_strSplit (@10up,',')		
	END
	

	CREATE TABLE #ExtraPT_Sel( ProductID  INT,
                                   Sporttype  INT,
                                   SubProduct VARCHAR(100),
                                   SuperID    INT,
							FromDate DATETIME,
							ToDate DATETIME,
                                   ExtraPT    DECIMAL(9, 8));
    INSERT INTO #ExtraPT_Sel
			 ( ProductID, Sporttype, SubProduct, SuperID, FromDate, ToDate, ExtraPT)
    SELECT ProductID, SportType, SubProduct, SuperId, FromDate, ToDate, SUM(ExtraPT) AS ExtraPT
    FROM bodb02.dbo.Acc_GroupExtraPTSetting a WITH ( NOLOCK )
    WHERE a.ProductID = 1
	   AND a.Sporttype = 0
	   AND a.SubProduct = ''
    GROUP BY ProductID, SportType, SubProduct, SuperId, FromDate, ToDate;

	IF @todate > @movebetsday
	BEGIN
		SELECT @f_date = CASE WHEN @fromdate <= @movebetsday THEN DATEADD(dd,1,@movebetsday) ELSE @fromdate END,
				@t_date = @todate 
				
		INSERT INTO @tmpSum (
			month 
			,username
			,tickets_won
			,tickets_lose 
			,stake_won 
			,stake_lose
			,member_won 
			,member_lose
			,ourPT_won 
			,ourPT_lose
		)
		 SELECT convert(varchar(7),winlostdate,120)
			,username
			,SUM(case when statusid = 112 then 1 else 0 end) as tickets_won
			,SUM(case when statusid = 113 then 1 else 0 end) as tickets_lose,
			SUM(CASE
				   WHEN statusid = 112
				   THEN stake * actualrate * (1 - tpositiontaking - ISNULL(a.ExtraPT, 0))
				   ELSE 0
			    END) AS stake_won,
			SUM(CASE
				   WHEN statusid = 113
				   THEN stake * actualrate * (1 - tpositiontaking - ISNULL(a.ExtraPT, 0))
				   ELSE 0
			    END) AS stake_lose,
			SUM(CASE
				   WHEN statusid = 112
				   THEN-(winlost - actual_stake) * actualrate
				   ELSE 0
			    END) AS member_won,
			SUM(CASE
				   WHEN statusid = 113
				   THEN-(winlost - actual_stake) * actualrate
				   ELSE 0
			    END) AS member_lose,
			SUM(CASE
				   WHEN statusid = 112
				   THEN(-(winlost - actual_stake)  * (1 - tpositiontaking - ISNULL(a.ExtraPT, 0)) - scomm  + scomm * ISNULL(a.ExtraPT, 0) / (1 - tpositiontaking) ) * actualrate
				   ELSE 0
			    END) AS ourPT_won,
			SUM(CASE
				   WHEN statusid = 113
				   THEN(-(winlost - actual_stake) * (1 - tpositiontaking - ISNULL(a.ExtraPT, 0)) - scomm  + scomm * ISNULL(a.ExtraPT, 0) / (1 - tpositiontaking)) * actualrate
				   ELSE 0
			    END) AS ourPT_lose
		 FROM rmBettrans WITH(NOLOCK)
		 INNER JOIN @tmpSelection b ON hdp2  =b.selection
		 INNER JOIN @tmpSport c ON transid2=c.sporttype
		 LEFT JOIN #ExtraPT_Sel AS a WITH (NOLOCK) ON srecommend = a.SuperId AND winlostdate BETWEEN a.FromDate AND a.Todate
		 WHERE recommend = @custid 
			AND winlostdate BETWEEN @f_date AND @t_date
			AND statusid IN (112,113)	
			AND ((@IsMixParlay=1 AND betteam ='1' AND bettype=29 AND matchid = 29 ) OR (@IsComboParlay= 1 AND bettype=29 AND betteam <>'1' AND matchid = 29) OR (@IsSingleMatchParlay=1 AND bettype=38))		
		 GROUP BY convert(varchar(7),winlostdate,120),username
	END
	
	IF @fromdate <= @movebetsday
	BEGIN
		IF @todate >= @balanceupday
		BEGIN
			SELECT @f_date = CASE WHEN @fromdate < @balanceupday THEN @balanceupday ELSE @fromdate END,
					@t_date = CASE WHEN @todate > @movebetsday THEN @movebetsday ELSE @todate END
			
			INSERT INTO @tmpSum (
				month 
				,username
				,tickets_won
				,tickets_lose 
				,stake_won 
				,stake_lose
				,member_won 
				,member_lose
				,ourPT_won 
				,ourPT_lose
			)
			SELECT 
				convert(varchar(7),a.winlostdate,120)
				,username
				,sum(case when a.statusid = 112 then betcount else 0 end) as tickets_won
				,sum(case when a.statusid = 113 then betcount else 0 end) as tickets_lose
				,sum(case when a.statusid = 112 then company_stake*actualrate - ISNULL(a.Extra_stake, 0) * actualrate else 0 end) as stake_won
				,sum(case when a.statusid = 113 then company_stake*actualrate - ISNULL(a.Extra_stake, 0) * actualrate else 0 end) as stake_lose
				,sum(case when a.statusid = 112 then -(a.winlost-a.stake)*actualrate else 0 end) as member_won
				,sum(case when a.statusid = 113 then -(a.winlost-a.stake)*actualrate else 0 end) as member_lose
				,sum(case when a.statusid = 112 then (company_winlost - ISNULL(a.Extra_winlost, 0) - ISNULL(a.scomm, 0) + ISNULL(a.Extra_comm, 0)) *actualrate else 0 end) as ourPT_won
				,sum(case when a.statusid = 113 then (company_winlost- ISNULL(a.Extra_winlost, 0) - ISNULL(a.scomm, 0) + ISNULL(a.Extra_comm, 0)) *actualrate else 0 end) as ourPT_lose	
			FROM rmSumWinloss a WITH(NOLOCK)
			INNER JOIN @tmpSelection b ON a.combo=b.selection
			INNER JOIN @tmpSport c ON a.sporttype=c.sporttype
			WHERE recommend = @custid
					AND a.winlostdate BETWEEN @f_date AND @t_date				
					AND a.statusid IN (112,113)
					AND currency <> 20				
					AND ((@IsMixParlay=1 AND (ISNULL(a.parlaytype,1) IN (1,2))) OR (@IsComboParlay= 1 AND ISNULL(a.parlaytype,1)=3) OR (@IsSingleMatchParlay = 1 AND parlaytype = 4))		
			GROUP BY convert(varchar(7),a.winlostdate,120),username
		END
		
		IF @fromdate < @balanceupday
		BEGIN
			SELECT @f_date = @fromdate, 
					@t_date = CASE WHEN @todate >= @balanceupday THEN @balanceupday -1 ELSE @todate END
			
			
			INSERT INTO @tmpSum (
				month 
				,username
				,tickets_won
				,tickets_lose 
				,stake_won 
				,stake_lose
				,member_won 
				,member_lose
				,ourPT_won 
				,ourPT_lose
			)
			SELECT 
				convert(varchar(7),a.winlostdate,120)
				,username
				,sum(case when a.statusid = 112 then betcount else 0 end) as tickets_won
				,sum(case when a.statusid = 113 then betcount else 0 end) as tickets_lose
				,sum(case when a.statusid = 112 then company_stake*actualrate - ISNULL(a.Extra_stake, 0) * actualrate else 0 end) as stake_won
				,sum(case when a.statusid = 113 then company_stake*actualrate - ISNULL(a.Extra_stake, 0) * actualrate else 0 end) as stake_lose
				,sum(case when a.statusid = 112 then -(a.winlost-a.stake)*actualrate else 0 end) as member_won
				,sum(case when a.statusid = 113 then -(a.winlost-a.stake)*actualrate else 0 end) as member_lose
				,sum(case when a.statusid = 112 then (company_winlost - ISNULL(a.Extra_winlost, 0) - ISNULL(a.scomm, 0) + ISNULL(a.Extra_comm, 0)) *actualrate else 0 end) as ourPT_won
				,sum(case when a.statusid = 113 then (company_winlost- ISNULL(a.Extra_winlost, 0) - ISNULL(a.scomm, 0) + ISNULL(a.Extra_comm, 0)) *actualrate else 0 end) as ourPT_lose			
			FROM rmSumWinloss_Old a WITH(NOLOCK)
			INNER JOIN @tmpSelection b ON a.combo=b.selection
			INNER JOIN @tmpSport c ON a.sporttype=c.sporttype
			WHERE recommend = @custid
					AND a.winlostdate BETWEEN @f_date AND @t_date				
					AND a.statusid IN (112,113)
					AND currency <> 20						
					AND ((@IsMixParlay=1 AND (ISNULL(a.parlaytype,1) IN (1,2))) OR (@IsComboParlay= 1 AND ISNULL(a.parlaytype,1)=3) OR (@IsSingleMatchParlay = 1 AND parlaytype = 4))		
			GROUP BY convert(varchar(7),a.winlostdate,120),username
		END
	END
	
	SELECT
		month 
		,username
		,sum(tickets_won) as tickets_won
		,sum(tickets_lose) as tickets_lose 
		,sum(stake_won) as stake_won  
		,sum(stake_lose) as stake_lose
		,sum(member_won) as member_won  
		,sum(member_lose) as member_lose
		,sum(ourPT_won) as ourPT_won  
		,sum(ourPT_lose) as ourPT_lose
	FROM @tmpSum
	GROUP BY month,username
	ORDER BY month,username		

	DROP TABLE #ExtraPT_Sel
GO
