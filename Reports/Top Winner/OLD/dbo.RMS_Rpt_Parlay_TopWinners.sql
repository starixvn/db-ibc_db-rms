/*<info serverAlias="DBRMS-bodb_RMS" executers="bodbRMSNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[RMS_Rpt_Parlay_TopWinners]
	@fromdate	DATETIME,
	@todate		DATETIME,
	@movebetsday DATETIME,
	@balanceUpday DATETIME = NULL,
	@limitedRow	INT = 20,
	@sporttype	TINYINT = null,
	@selection	VARCHAR(100) = ''
AS
	/*
		Created: Johnson	
		Date: 2012-11-05
		DB: DBRMS/bodb_RMS
		Task: Get top members won mix parlay
		
		Revisions:
			- 20121214@Johnson: get data before balanceupday from rmSumWinloss_Old
			- 20130125@Johnson: move bettransParlay from bodb02 to bodb_RMS and rename to rmBettrans
			- 20130225@Johnson: include lose tickets to calculate top winners
			- 20130315@Johnson: calculate average win odds by formula : Winning Amount/Stake
			- 20130813@Johnson: add combination filter
			- 20130918@Johnson: change to use table rmSumWinloss and rmSumWinloss_old instead rmSumWinloss2 and rmSumWinloss_old2 
			- 20180927@Jacob: Apply Extra PT and Super Comm to Report.  RedmineID: #100951 		
		Parameter's Explanation:
		Example: exec [RMS_Rpt_Parlay_TopWinners] @fromdate = '2018-09-01', @todate='2018-10-30', @movebetsday='2018-09-06',@balanceupday='2018-09-28'
	*/ 
SET NOCOUNT ON
	DECLARE @f_date DATETIME,
			@t_date DATETIME
			
	DECLARE @tmpSum TABLE (custid INT
		,username VARCHAR(30)
		,currency INT
		,stake MONEY
		,winlost MONEY
		,company_winlost MONEY
		,stake_baseRM MONEY
		,winlost_baseRM MONEY
		,company_winlost_baseRM MONEY
		,betcount INT)	
	
	DECLARE @tmpSelection TABLE(selection tinyint)
	DECLARE @6UP VARCHAR(200)	
	
	INSERT INTO @tmpSelection
	SELECT val
	FROM f_RMS_strSplit (@selection,',')
	
	--Check selection is 6-UP
	IF EXISTS(SELECT 1 FROM @tmpSelection WHERE selection = 6)
	BEGIN
		SELECT @6up = '7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30'

		INSERT INTO @tmpSelection
		SELECT val
		FROM f_RMS_strSplit (@6up,',')		
	END
	
	IF @todate > @movebetsday
	BEGIN
		SELECT @f_date = CASE WHEN @fromdate <= @movebetsday THEN DATEADD(dd,1,@movebetsday) ELSE @fromdate END,
				@t_date = @todate 
				
		INSERT INTO @tmpSum (custid
			,username
			,currency
			,stake
			,winlost
			,company_winlost
			,stake_baseRM
			,winlost_baseRM
			,company_winlost_baseRM
			,betcount			
		)
		 SELECT custid
			 ,username
			 ,currency
			 ,SUM(stake)
			 ,SUM(winlost - actual_stake)
			 ,SUM(-(winlost - actual_stake)  * (1 - tpositiontaking - ISNULL(a.ExtraPT, 0)) - scomm  + scomm * ISNULL(a.ExtraPT, 0) / (1 - tpositiontaking) )
			 ,SUM(stake*actualrate)
			 ,SUM((winlost-actual_stake)*actualrate)
			 ,SUM((-(winlost - actual_stake)  * (1 - tpositiontaking - ISNULL(a.ExtraPT, 0)) - scomm  + scomm * ISNULL(a.ExtraPT, 0) / (1 - tpositiontaking) ) * actualrate)
			 ,COUNT(1) as betcount			
		 FROM rmBettrans WITH(NOLOCK)
		 LEFT JOIN bodb02.dbo.Acc_GroupExtraPTSetting AS a WITH (NOLOCK) ON srecommend = a.SuperId
																				AND winlostdate BETWEEN a.FromDate AND a.Todate
																				AND a.ProductID = 1
																				AND a.Sporttype = 0
																				AND a.SubProduct = ''
		 WHERE winlostdate BETWEEN @f_date AND @t_date
			AND matchid = 9 
			AND statusid IN (112,113)
			AND liveawayscore = ISNULL(@sporttype,liveawayscore)
			AND right(betcheck,len(betcheck)-1) IN (SELECT selection FROM @tmpSelection)
		 GROUP BY custid, username, currency
	END
	IF @fromdate <= @movebetsday
	BEGIN
		IF @todate >= @balanceupday
		BEGIN
			SELECT @f_date = CASE WHEN @fromdate < @balanceupday THEN @balanceupday ELSE @fromdate END,
					@t_date = CASE WHEN @todate > @movebetsday THEN @movebetsday ELSE @todate END
			
			INSERT INTO @tmpSum (custid
				,username
				,currency
				,stake
				,winlost
				,company_winlost
				,stake_baseRM
				,winlost_baseRM
				,company_winlost_baseRM
				,betcount				
			)
			SELECT a.custid
				,username
				,currency
				,SUM(a.stake)
				,SUM(a.winlost-a.stake)
				,SUM((company_winlost - ISNULL(e.winlost, 0) - ISNULL(e.scomm, 0) + ISNULL(e.comm, 0)) )
				,SUM(a.stake*a.actualrate)
				,SUM((a.winlost-a.stake)*a.actualrate)
				,SUM((company_winlost - ISNULL(e.winlost, 0) - ISNULL(e.scomm, 0) + ISNULL(e.comm, 0)) *actualrate )				
				,SUM(betcount)				
			FROM rmSumWinloss a WITH(NOLOCK)
			LEFT JOIN rmSumWinLossExtraPT e WITH(NOLOCK) ON a.[custid] = e.[custid] AND a.[winlostdate] = e.[winlostdate] AND a.[sporttype] = e.[sporttype] AND a.[statusid] = e.[statusid] AND a.[combo] = e.[combo]
			WHERE a.winlostdate BETWEEN @f_date AND @t_date
				AND a.sporttype = ISNULL(@sporttype,a.sporttype)
				AND a.statusid IN (112,113)
				AND a.combo IN (SELECT selection FROM @tmpSelection WHERE selection <=6)
			GROUP BY a.custid, username, currency
		END
		IF @fromdate < @balanceupday
		BEGIN
			SELECT @f_date = @fromdate, 
					@t_date = CASE WHEN @todate >= @balanceupday THEN @balanceupday -1 ELSE @todate END
			
			INSERT INTO @tmpSum (custid
				,username
				,currency
				,stake
				,winlost
				,company_winlost
				,stake_baseRM
				,winlost_baseRM
				,company_winlost_baseRM
				,betcount				
			)
			SELECT a.custid
				,username
				,currency
				,SUM(a.stake)
				,SUM(a.winlost-a.stake)
				,SUM((company_winlost - ISNULL(e.winlost, 0) - ISNULL(e.scomm, 0) + ISNULL(e.comm, 0)) )
				,SUM(a.stake*a.actualrate)
				,SUM((a.winlost-a.stake)*actualrate)
				,SUM((company_winlost - ISNULL(e.winlost, 0) - ISNULL(e.scomm, 0) + ISNULL(e.comm, 0)) *actualrate )				
				,SUM(betcount)				
			FROM rmSumWinloss_Old a WITH(NOLOCK)
			LEFT JOIN rmSumWinLossExtraPT_Old e WITH(NOLOCK) ON a.[custid] = e.[custid] AND a.[winlostdate] = e.[winlostdate] AND a.[sporttype] = e.[sporttype] AND a.[statusid] = e.[statusid] AND a.[combo] = e.[combo]
			WHERE a.winlostdate BETWEEN @f_date AND @t_date
				AND a.sporttype = ISNULL(@sporttype,a.sporttype)
				AND a.statusid IN (112,113)
				AND a.combo IN (SELECT selection FROM @tmpSelection WHERE selection <=6)
			GROUP BY a.custid, username, currency
		END
	END
	
	;WITH B AS 
	(
		SELECT TOP (@limitedRow) custid
				,username
				,currency
				,SUM(stake) as stake
				,SUM(winlost) as winlost 
				,SUM(company_winlost) as company_winlost
				,SUM(stake_baseRM) as stake_baseRM
				,SUM(winlost_baseRM) as winlost_baseRM
				,SUM(company_winlost_baseRM) as company_winlost_baseRM
				,SUM(betcount) as betcount
				,SUM(winlost_baseRM)/SUM(stake_baseRM) as avg_odds
		FROM @tmpSum		
		GROUP BY custid, username, currency
		HAVING SUM(winlost_baseRM) > 0
		ORDER BY sum(winlost_baseRM) DESC
	)

	SELECT b.custid
			,b.username
			,e.currency
			,stake
			,winlost 
			,company_winlost
			,stake_baseRM
			,winlost_baseRM			
			,company_winlost_baseRM
			,winlost_baseRM/stake_baseRM as margin
			,betcount
			,avg_odds
			,ISNULL(c.level,0) as level
	FROM B b
		INNER JOIN bodb02.dbo.Exchange e WITH(NOLOCK) ON b.currency = e.exchangeid
		LEFT JOIN rmCustomer c WITH(NOLOCK) ON b.custid = c.custid
		
	
	
GO