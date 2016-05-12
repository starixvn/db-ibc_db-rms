ALTER PROCEDURE [dbo].[RMS_Rpt_ComboParlay_Winloss]
	@fromdate	DATETIME,
	@todate		DATETIME,
	@movebetsday DATETIME,
	@balanceUpday DATETIME = NULL,
	@sporttype INT = null,
	@bettype INT = 9,
	@selection VARCHAR(100)='',
	@ParlayType	VARCHAR(10)=''
AS
	/*
		Created: Winnie
		Date: 2016-05-11
		DB: DBRMS/bodb_RMS
		Task: report comboparlay winloss
		
		Revisions:			
		Parameter's Explanation:
			- @sporttype = '1' : soccer only
						= '2' : Other sports
						= '3' : combined sports
			
	*/
SET NOCOUNT ON
	DECLARE @f_date DATETIME,
			@t_date DATETIME
			
	DECLARE @rptWinloss TABLE(
		winlostdate DATETIME,
		combo	INT,
		tickets_won	INT,
		tickets_lose INT,
		stake_won MONEY,
		stake_lose MONEY,
		member_won MONEY,
		member_lose MONEY,
		ourPT_won MONEY,
		ourPT_lose MONEY
	)
	DECLARE @tmpSelection TABLE(selection tinyint)	
	DECLARE @10UP VARCHAR(500),@all varchar(500)
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
	
	IF @todate > @movebetsday
	BEGIN
		SELECT @f_date = CASE WHEN @fromdate <= @movebetsday THEN DATEADD(dd,1,@movebetsday) ELSE @fromdate END,
				@t_date = @todate
		
		INSERT INTO @rptWinloss(
				winlostdate
				,combo
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
			winlostdate
			,CASE WHEN bettype=9 THEN right(betcheck,len(betcheck)-1) ELSE hdp2 END
			,sum(case when statusid = 112 then 1 else 0 end) as tickets_won
			,sum(case when statusid = 113 then 1 else 0 end) as tickets_lose
			,sum(case when statusid = 112 then stake*actualrate*(1-tpositiontaking) else 0 end) as stake_won
			,sum(case when statusid = 113 then stake*actualrate*(1-tpositiontaking) else 0 end) as stake_lose
			,sum(case when statusid = 112 then -(winlost-actual_stake)*actualrate else 0 end) as member_won
			,sum(case when statusid = 113 then -(winlost-actual_stake)*actualrate else 0 end) as member_lose			
			,sum(case when statusid = 112 then -(winlost-actual_stake)*actualrate*(1-tpositiontaking) else 0 end) as ourPT_won
			,sum(case when statusid = 113 then -(winlost-actual_stake)*actualrate*(1-tpositiontaking) else 0 end) as ourPT_lose
		FROM rmBettrans WITH(NOLOCK)
		INNER JOIN @tmpSelection b ON CASE WHEN bettype=9 THEN right(betcheck,len(betcheck)-1) ELSE hdp2 END =b.selection
		 WHERE winlostdate BETWEEN @f_date AND @t_date
			AND matchid IN(9,29) 
			AND statusid IN (112,113)
			AND liveawayscore = ISNULL(@sporttype,liveawayscore)
			AND currency <> 20
			AND (@_parlayType=0 OR (@_parlayType=1 AND betteam =1 AND bettype=29)OR (@_parlayType=1 AND bettype=9) OR (@_parlayType=2 AND bettype=29 AND betteam <>1 ))		
			
		GROUP BY winlostdate,CASE WHEN bettype=9 THEN right(betcheck,len(betcheck)-1) ELSE hdp2 END
	END
	
	IF @fromdate <= @movebetsday
	BEGIN
		IF @todate >= @balanceupday
		BEGIN
			SELECT @f_date = CASE WHEN @fromdate < @balanceupday THEN @balanceupday ELSE @fromdate END,
					@t_date = CASE WHEN @todate > @movebetsday THEN @movebetsday ELSE @todate END
			
			INSERT INTO @rptWinloss(
				winlostdate
				,combo
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
				winlostdate
				,combo
				,sum(case when statusid = 112 then betcount else 0 end) as tickets_won
				,sum(case when statusid = 113 then betcount else 0 end) as tickets_lose
				,sum(case when statusid = 112 then company_stake*actualrate else 0 end) as stake_won
				,sum(case when statusid = 113 then company_stake*actualrate else 0 end) as stake_lose
				,sum(case when statusid = 112 then -(winlost-stake)*actualrate else 0 end) as member_won
				,sum(case when statusid = 113 then -(winlost-stake)*actualrate else 0 end) as member_lose
				,sum(case when statusid = 112 then company_winlost*actualrate else 0 end) as ourPT_won
				,sum(case when statusid = 113 then company_winlost*actualrate else 0 end) as ourPT_lose			
			FROM rmSumWinloss a WITH(NOLOCK)
			INNER JOIN @tmpSelection b ON a.combo=b.selection
			WHERE winlostdate BETWEEN @f_date AND @t_date				
					AND statusid IN (112,113)
					AND currency <> 20
					AND sporttype = ISNULL(@sporttype, sporttype)
					AND (@_parlayType=0 OR (@_parlayType=1 AND a.IsMixParlay=1) OR (@_parlayType=2 AND a.IsMixParlay<>1))	
					
			GROUP BY winlostdate, combo
		END
		IF @fromdate < @balanceupday
		BEGIN
			SELECT @f_date = @fromdate, 
					@t_date = CASE WHEN @todate >= @balanceupday THEN @balanceupday -1 ELSE @todate END
			
			INSERT INTO @rptWinloss(
				winlostdate
				,combo
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
				winlostdate
				,combo
				,sum(case when statusid = 112 then betcount else 0 end) as tickets_won
				,sum(case when statusid = 113 then betcount else 0 end) as tickets_lose
				,sum(case when statusid = 112 then company_stake*actualrate else 0 end) as stake_won
				,sum(case when statusid = 113 then company_stake*actualrate else 0 end) as stake_lose
				,sum(case when statusid = 112 then -(winlost-stake)*actualrate else 0 end) as member_won
				,sum(case when statusid = 113 then -(winlost-stake)*actualrate else 0 end) as member_lose
				,sum(case when statusid = 112 then company_winlost*actualrate else 0 end) as ourPT_won
				,sum(case when statusid = 113 then company_winlost*actualrate else 0 end) as ourPT_lose			
			FROM rmSumWinloss_Old a WITH(NOLOCK)
			INNER JOIN @tmpSelection b ON a.combo=b.selection
			WHERE winlostdate BETWEEN @f_date AND @t_date				
				AND statusid IN (112,113)
				AND currency <> 20	
				AND sporttype = ISNULL(@sporttype, sporttype)
				AND (@_parlayType=0 OR (@_parlayType=1 AND a.IsMixParlay=1) OR (@_parlayType=2 AND a.IsMixParlay<>1))	
				
			GROUP BY winlostdate, combo			
		END			
	END
	
	SELECT winlostdate
				,CASE WHEN combo>10 THEN 10 ELSE combo END AS combo
				,SUM(tickets_won) AS tickets_won
				,SUM(tickets_lose) AS tickets_lose
				,SUM(stake_won) AS stake_won
				,SUM(stake_lose) AS stake_lose
				,SUM(member_won) AS member_won
				,SUM(member_lose) AS member_lose
				,SUM(ourPT_won) AS ourPT_won
				,SUM(ourPT_lose) AS ourPT_lose
	 FROM @rptWinloss
	 GROUP BY  winlostdate, CASE WHEN combo>10 THEN 10 ELSE combo END
	 ORDER BY winlostdate ASC, combo ASC
	
	
GO
GRANT EXECUTE ON [dbo].[RMS_Rpt_ComboParlay_Winloss] TO [bodbRMSNet]