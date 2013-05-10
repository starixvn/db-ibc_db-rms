ALTER PROCEDURE [dbo].[RMS_Rpt_Parlay_TopWinners]
	@fromdate	DATETIME,
	@todate		DATETIME,
	@movebetsday DATETIME,
	@balanceUpday DATETIME = NULL,
	@limitedRow	INT = 20,
	@sporttype	TINYINT = null
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
		Parameter's Explanation:
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
	
	IF @todate > @movebetsday
	BEGIN
		SELECT @f_date = CASE WHEN @fromdate < @movebetsday THEN DATEADD(dd,1,@movebetsday) ELSE @fromdate END,
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
			 ,SUM(-(winlost-actual_stake)*(1-tpositiontaking))
			 ,SUM(stake*actualrate)
			 ,SUM((winlost-actual_stake)*actualrate)
			 ,SUM(-(winlost-actual_stake)*(1-tpositiontaking)*actualrate)
			 ,COUNT(1) as betcount			
		 FROM rmBettrans WITH(NOLOCK)
		 WHERE winlostdate BETWEEN @f_date AND @t_date
			AND matchid = 9 
			AND statusid IN (112,113)
			AND liveawayscore = ISNULL(@sporttype,liveawayscore)
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
			SELECT custid
				,username
				,currency
				,SUM(stake)
				,SUM(winlost-stake)
				,SUM(company_winlost)
				,SUM(stake*actualrate)
				,SUM((winlost-stake)*actualrate)
				,SUM(company_winlost*actualrate)
				,SUM(betcount)				
			FROM rmSumWinloss WITH(NOLOCK)
			WHERE winlostdate BETWEEN @f_date AND @t_date
				AND sporttype = ISNULL(@sporttype,sporttype)
				AND statusid IN (112,113)
			GROUP BY custid, username, currency
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
			SELECT custid
				,username
				,currency
				,SUM(stake)
				,SUM(winlost-stake)
				,SUM(company_winlost)
				,SUM(stake*actualrate)
				,SUM((winlost-stake)*actualrate)
				,SUM(company_winlost*actualrate)
				,SUM(betcount)				
			FROM rmSumWinloss_Old WITH(NOLOCK)
			WHERE winlostdate BETWEEN @f_date AND @t_date
				AND sporttype = ISNULL(@sporttype,sporttype)
				AND statusid IN (112,113)
			GROUP BY custid, username, currency
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
GRANT EXECUTE ON [dbo].[RMS_Rpt_Parlay_TopWinners] TO [bodbRMSNet]