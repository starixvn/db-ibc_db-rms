ALTER PROCEDURE [dbo].[RMS_Rpt_Parlay_Winloss]
	@fromdate	DATETIME,
	@todate		DATETIME,
	@movebetsday DATETIME,
	@balanceUpday DATETIME = NULL,
	@bettype INT = 9
AS
	/*
		Created: Johnson
		Date: 2013-07-11
		DB: DBRMS/bodb_RMS
		Task: report parlay winloss
		
		Revisions:
		
		Parameter's Explanation:
	*/
SET NOCOUNT ON
	DECLARE @f_date DATETIME,
			@t_date DATETIME
			
	DECLARE @rptWinloss TABLE(
		winlostdate DATETIME,
		tickets_won	INT,
		tickets_lose INT,
		stake_won MONEY,
		stake_lose MONEY,
		member_won MONEY,
		member_lose MONEY,
		ourPT_won MONEY,
		ourPT_lose MONEY
	)
	
	IF @todate > @movebetsday
	BEGIN
		SELECT @f_date = CASE WHEN @fromdate < @movebetsday THEN DATEADD(dd,1,@movebetsday) ELSE @fromdate END,
				@t_date = @todate
		
		INSERT INTO @rptWinloss(
				winlostdate
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
			,sum(case when statusid = 112 then 1 else 0 end) as tickets_won
			,sum(case when statusid = 113 then 1 else 0 end) as tickets_lose
			,sum(case when statusid = 112 then stake*actualrate*(1-tpositiontaking) else 0 end) as stake_won
			,sum(case when statusid = 113 then stake*actualrate*(1-tpositiontaking) else 0 end) as stake_lose
			,sum(case when statusid = 112 then -(winlost-actual_stake)*actualrate else 0 end) as member_won
			,sum(case when statusid = 113 then -(winlost-actual_stake)*actualrate else 0 end) as member_lose			
			,sum(case when statusid = 112 then -(winlost-actual_stake)*actualrate*(1-tpositiontaking) else 0 end) as ourPT_won
			,sum(case when statusid = 113 then -(winlost-actual_stake)*actualrate*(1-tpositiontaking) else 0 end) as ourPT_lose
		FROM rmBettrans WITH(NOLOCK)
		 WHERE winlostdate BETWEEN @f_date AND @t_date
			AND matchid = 9 
			AND statusid IN (112,113)
		GROUP BY winlostdate
	END
	
	IF @fromdate <= @movebetsday
	BEGIN
		IF @todate >= @balanceupday
		BEGIN
			SELECT @f_date = CASE WHEN @fromdate < @balanceupday THEN @balanceupday ELSE @fromdate END,
					@t_date = CASE WHEN @todate > @movebetsday THEN @movebetsday ELSE @todate END
			
			INSERT INTO @rptWinloss(
				winlostdate
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
				,sum(case when statusid = 112 then betcount else 0 end) as tickets_won
				,sum(case when statusid = 113 then betcount else 0 end) as tickets_lose
				,sum(case when statusid = 112 then company_stake*actualrate else 0 end) as stake_won
				,sum(case when statusid = 113 then company_stake*actualrate else 0 end) as stake_lose
				,sum(case when statusid = 112 then -(winlost-stake)*actualrate else 0 end) as member_won
				,sum(case when statusid = 113 then -(winlost-stake)*actualrate else 0 end) as member_lose
				,sum(case when statusid = 112 then company_winlost*actualrate else 0 end) as ourPT_won
				,sum(case when statusid = 113 then company_winlost*actualrate else 0 end) as ourPT_lose			
			FROM rmSumWinloss WITH(NOLOCK)
			WHERE winlostdate BETWEEN @f_date AND @t_date				
					AND statusid IN (112,113)
			GROUP BY winlostdate
		END
		IF @fromdate < @balanceupday
		BEGIN
			SELECT @f_date = @fromdate, 
					@t_date = CASE WHEN @todate >= @balanceupday THEN @balanceupday -1 ELSE @todate END
			
			INSERT INTO @rptWinloss(
				winlostdate
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
				,sum(case when statusid = 112 then betcount else 0 end) as tickets_won
				,sum(case when statusid = 113 then betcount else 0 end) as tickets_lose
				,sum(case when statusid = 112 then company_stake*actualrate else 0 end) as stake_won
				,sum(case when statusid = 113 then company_stake*actualrate else 0 end) as stake_lose
				,sum(case when statusid = 112 then -(winlost-stake)*actualrate else 0 end) as member_won
				,sum(case when statusid = 113 then -(winlost-stake)*actualrate else 0 end) as member_lose
				,sum(case when statusid = 112 then company_winlost*actualrate else 0 end) as ourPT_won
				,sum(case when statusid = 113 then company_winlost*actualrate else 0 end) as ourPT_lose			
			FROM rmSumWinloss_Old WITH(NOLOCK)
			WHERE winlostdate BETWEEN @f_date AND @t_date				
				AND statusid IN (112,113)	
			GROUP BY winlostdate			
		END			
	END
	
	SELECT * FROM @rptWinloss
	ORDER BY winlostdate ASC
	
	
GO
GRANT EXECUTE ON [dbo].[RMS_Rpt_Parlay_Winloss] TO [bodbRMSNet]