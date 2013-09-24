  ALTER PROCEDURE [dbo].[RMS_Rpt_Parlay_Winloss_Ag]
	@custid		INT,
	@fromdate	DATETIME,
	@todate		DATETIME,
	@movebetsday DATETIME,
	@balanceUpday DATETIME = NULL,
	@sporttype	TINYINT = null,
	@selection	VARCHAR(100) = ''
AS
	/*
		Created: Johnson	
		Date: 2013-09-24
		DB: DBRMS/bodb_RMS
		Task: Get report win loss for downlines by specific Agent
		
		Revisions:
	
		Parameter's Explanation:
			- @sporttype = '1' : soccer only
						= '2' : Other sports
						= '3' : combined sports
	*/ 
SET NOCOUNT ON
	DECLARE @f_date DATETIME,
			@t_date DATETIME
	
	DECLARE @tmpSum TABLE (
		month VARCHAR(7)
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
				
		INSERT INTO @tmpSum (
			month 
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
			,SUM(case when statusid = 112 then 1 else 0 end) as tickets_won
			,SUM(case when statusid = 113 then 1 else 0 end) as tickets_lose
			,SUM(case when statusid = 112 then stake*actualrate*(1-tpositiontaking) else 0 end) as stake_won
			,SUM(case when statusid = 113 then stake*actualrate*(1-tpositiontaking) else 0 end) as stake_lose
			,SUM(case when statusid = 112 then -(winlost - actual_stake)*actualrate else 0 end) as member_won
			,SUM(case when statusid = 113 then -(winlost - actual_stake)*actualrate else 0 end) as member_lose
			,sum(case when statusid = 112 then -(winlost-actual_stake)*actualrate*(1-tpositiontaking) else 0 end) as ourPT_won
			,sum(case when statusid = 113 then -(winlost-actual_stake)*actualrate*(1-tpositiontaking) else 0 end) as ourPT_lose
		 FROM rmBettrans WITH(NOLOCK)
		 WHERE recommend = @custid 
			AND winlostdate BETWEEN @f_date AND @t_date
			AND matchid = 9 
			AND statusid IN (112,113)
			AND liveawayscore = ISNULL(@sporttype,liveawayscore)
			AND right(betcheck,len(betcheck)-1) IN (SELECT selection FROM @tmpSelection)
		 GROUP BY convert(varchar(7),winlostdate,120)
	END
	
	IF @fromdate <= @movebetsday
	BEGIN
		IF @todate >= @balanceupday
		BEGIN
			SELECT @f_date = CASE WHEN @fromdate < @balanceupday THEN @balanceupday ELSE @fromdate END,
					@t_date = CASE WHEN @todate > @movebetsday THEN @movebetsday ELSE @todate END
			
			INSERT INTO @tmpSum (
				month 
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
				convert(varchar(7),winlostdate,120)
				,sum(case when statusid = 112 then betcount else 0 end) as tickets_won
				,sum(case when statusid = 113 then betcount else 0 end) as tickets_lose
				,sum(case when statusid = 112 then company_stake*actualrate else 0 end) as stake_won
				,sum(case when statusid = 113 then company_stake*actualrate else 0 end) as stake_lose
				,sum(case when statusid = 112 then -(winlost-stake)*actualrate else 0 end) as member_won
				,sum(case when statusid = 113 then -(winlost-stake)*actualrate else 0 end) as member_lose
				,sum(case when statusid = 112 then company_winlost*actualrate else 0 end) as ourPT_won
				,sum(case when statusid = 113 then company_winlost*actualrate else 0 end) as ourPT_lose			
			FROM rmSumWinloss WITH(NOLOCK)
			WHERE recommend = @custid
					AND winlostdate BETWEEN @f_date AND @t_date				
					AND statusid IN (112,113)
					AND currency <> 20
					AND sporttype = ISNULL(@sporttype, sporttype)
					AND combo IN (SELECT selection FROM @tmpSelection WHERE selection <=6)
			GROUP BY convert(varchar(7),winlostdate,120)
		END
		
		IF @fromdate < @balanceupday
		BEGIN
			SELECT @f_date = @fromdate, 
					@t_date = CASE WHEN @todate >= @balanceupday THEN @balanceupday -1 ELSE @todate END
			
			
			INSERT INTO @tmpSum (
				month 
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
				convert(varchar(7),winlostdate,120)
				,sum(case when statusid = 112 then betcount else 0 end) as tickets_won
				,sum(case when statusid = 113 then betcount else 0 end) as tickets_lose
				,sum(case when statusid = 112 then company_stake*actualrate else 0 end) as stake_won
				,sum(case when statusid = 113 then company_stake*actualrate else 0 end) as stake_lose
				,sum(case when statusid = 112 then -(winlost-stake)*actualrate else 0 end) as member_won
				,sum(case when statusid = 113 then -(winlost-stake)*actualrate else 0 end) as member_lose
				,sum(case when statusid = 112 then company_winlost*actualrate else 0 end) as ourPT_won
				,sum(case when statusid = 113 then company_winlost*actualrate else 0 end) as ourPT_lose			
			FROM rmSumWinloss_Old WITH(NOLOCK)
			WHERE recommend = @custid
					AND winlostdate BETWEEN @f_date AND @t_date				
					AND statusid IN (112,113)
					AND currency <> 20
					AND sporttype = ISNULL(@sporttype, sporttype)
					AND combo IN (SELECT selection FROM @tmpSelection WHERE selection <=6)
			GROUP BY convert(varchar(7),winlostdate,120)
		END
	END
	
	SELECT
		month 
		,sum(tickets_won) as tickets_won
		,sum(tickets_lose) as tickets_lose 
		,sum(stake_won) as stake_won  
		,sum(stake_lose) as stake_lose
		,sum(member_won) as member_won  
		,sum(member_lose) as member_lose
		,sum(ourPT_won) as ourPT_won  
		,sum(ourPT_lose) as ourPT_lose
	FROM @tmpSum
	GROUP BY month		

GO
GRANT EXECUTE ON [dbo].[RMS_Rpt_Parlay_Winloss_Ag] TO [bodbRMSNet]		