ALTER PROCEDURE [dbo].[RMS_Rpt_ComboParlay_TopWinners]
	@fromdate	DATETIME,
	@todate		DATETIME,
	@movebetsday DATETIME,
	@balanceUpday DATETIME = NULL,
	@limitedRow	INT = 20,
	@sporttype	VARCHAR(100)='',
	@selection	VARCHAR(100) = '',
	@ParlayType	VARCHAR(10)=''
AS
	/*
		Created: Winnie	
		Date: 2016-05-11
		DB: DBRMS/bodb_RMS
		Task: Get top members won comno parlay
		
		Revisions:
		Parameter's Explanation:
	*/ 
SET NOCOUNT ON
	DECLARE @f_date DATETIME,
			@t_date DATETIME
	DECLARE @tmpSport TABLE (sporttype int)		
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

	DECLARE @tmpParlayType TABLE (parlaytype tinyint)
	DECLARE @_ParlayType	TINYINT

	INSERT INTO @tmpParlayType
	SELECT val
	FROM f_RMS_strSplit (@ParlayType,',')
	IF EXISTS(SELECT TOP 1 1 FROM @tmpParlayType WHERE parlaytype = 1 ) AND EXISTS(SELECT TOP 1 1 FROM @tmpParlayType WHERE parlaytype = 2)
		SELECT @_ParlayType=0
	ELSE IF EXISTS(SELECT TOP 1 1 FROM @tmpParlayType WHERE parlaytype = 1 )
		SELECT @_ParlayType=1
	ELSE IF EXISTS(SELECT TOP 1 1 FROM @tmpParlayType WHERE parlaytype = 2 )
		SELECT @_ParlayType=2
	
	DECLARE @tmpSelection TABLE(selection tinyint)
	DECLARE @10UP VARCHAR(500),@all varchar(500)
	
	INSERT INTO @tmpSelection
	SELECT val
	FROM f_RMS_strSplit (@selection,',')
	
	INSERT INTO @tmpSport (sporttype)
	SELECT val
	FROM f_RMS_strSplit (@sporttype,',')
	IF EXISTS (SELECT TOP 1 1 FROM @tmpSport WHERE sporttype=-2)
	BEGIN
	INSERT INTO @tmpSport
	SELECT SportType FROM bodb02.dbo.Sports(NOLOCK) WHERE SportType NOT IN (1,2,3,4,5,6,7,8,9,11,43)
	END
	
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
			 ,SUM(-(winlost-actual_stake)*(1-tpositiontaking))
			 ,SUM(stake*actualrate)
			 ,SUM((winlost-actual_stake)*actualrate)
			 ,SUM(-(winlost-actual_stake)*(1-tpositiontaking)*actualrate)
			 ,COUNT(1) as betcount			
		 FROM rmBettrans a WITH(NOLOCK)
		 INNER JOIN @tmpSelection b ON CASE WHEN bettype=9 THEN right(betcheck,len(betcheck)-1) ELSE hdp2 END =b.selection
		 INNER JOIN @tmpSport c ON a.transid2=c.sporttype
		 WHERE winlostdate BETWEEN @f_date AND @t_date
			AND matchid IN(9,29)
			AND statusid IN (112,113)				
			AND (@_parlayType=0 OR (@_parlayType=1 AND betteam ='1' AND bettype=29)OR (@_parlayType=1 AND bettype=9) OR (@_parlayType=2 AND bettype=29 AND betteam <>'1' ))		
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
			FROM rmSumWinloss a WITH(NOLOCK)
			INNER JOIN @tmpSelection b ON a.combo=b.selection
			INNER JOIN @tmpSport c ON a.sporttype=c.sporttype
			WHERE winlostdate BETWEEN @f_date AND @t_date				
				AND statusid IN (112,113)	
				AND (@_parlayType=0 OR (@_parlayType=1 AND a.parlaytype IN (1,2)) OR (@_parlayType=2 AND a.parlaytype=3))		
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
			FROM rmSumWinloss_Old a WITH(NOLOCK)
			INNER JOIN @tmpSelection b ON a.combo=b.selection
			INNER JOIN @tmpSport c ON a.sporttype=c.sporttype
			WHERE winlostdate BETWEEN @f_date AND @t_date				
				AND statusid IN (112,113)			
				AND (@_parlayType=0 OR (@_parlayType=1 AND a.parlaytype IN (1,2)) OR (@_parlayType=2 AND a.parlaytype=3))			
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
GRANT EXECUTE ON [dbo].[RMS_Rpt_ComboParlay_TopWinners] TO [bodbRMSNet]