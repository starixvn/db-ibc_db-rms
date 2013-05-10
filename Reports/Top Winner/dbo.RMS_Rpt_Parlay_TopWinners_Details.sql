ALTER PROCEDURE [dbo].[RMS_Rpt_Parlay_TopWinners_Details]
	@custid			INT,
	@fromdate		DATETIME,
	@todate			DATETIME,
	@sporttype		TINYINT = NULL,
	@movebetsday	DATETIME
	
AS
	/*
		Created: Johnson
		Date: 2012-11-06
		DB: DBRMS/bodb_RMS
		Task: Parlay bet list for top winners
		
		Revisions:
			- 20130125@Johnson: move bettransParlay from bodb02 to bodb_RMS and rename to rmBettrans
			- 20130225@Johnson: include lose tickets in report
		Parameter's Explanation:
	*/
SET NOCOUNT ON
	DECLARE @f_date DATETIME,
			@t_date DATETIME			
	DECLARE @tmpBettrans TABLE (transid BIGINT PRIMARY KEY
				,sporttype TINYINT
				,stake MONEY
				,winlost MONEY
				,company_winlost MONEY
				,stake_baseRM MONEY
				,winlost_baseRM MONEY
				,company_winlost_baseRM MONEY
				,combo TINYINT
				,odds SMALLMONEY
			)
	
	IF @todate > @movebetsday
	BEGIN
		SELECT @f_date = CASE WHEN @fromdate > @movebetsday THEN @fromdate ELSE dateadd(dd,1,@movebetsday) END,
				@t_date = @todate
		
		INSERT INTO @tmpBettrans (transid
				,sporttype
				,stake
				,winlost
				,company_winlost
				,stake_baseRM
				,winlost_baseRM
				,company_winlost_baseRM
				,combo
				,odds)
		SELECT transid
			,liveawayscore
			,stake
			,winlost-actual_stake
			,-(winlost-actual_stake)*(1-tpositiontaking) as company_winlost
			,stake*actualrate
			,(winlost-actual_stake)*actualrate
			,-(winlost-actual_stake)*(1-tpositiontaking)*actualrate as company_winlost_baseRM
			,RIGHT(betcheck,len(betcheck)-1)
			,modds
		FROM rmBettrans WITH(NOLOCK)
		WHERE custid = @custid
			AND matchid = 9 
			AND winlostdate BETWEEN @f_date AND @t_date
			AND statusid IN (112,113)
	END
	IF @fromdate < @movebetsday
	BEGIN
		SELECT @f_date = @fromdate, 
			@t_date = CASE WHEN @todate > @MoveBetsDay THEN @MoveBetsDay ELSE @todate END
					
			INSERT INTO @tmpBettrans (transid
				,sporttype
				,stake
				,winlost
				,company_winlost
				,stake_baseRM
				,winlost_baseRM
				,company_winlost_baseRM
				,combo
				,odds)
			SELECT transid
				,liveawayscore
				,stake
				,winlost-actual_stake
				,-(winlost-actual_stake)*(1-tpositiontaking)
				,stake*actualrate
				,(winlost-actual_stake)*actualrate
				,-(winlost-actual_stake)*(1-tpositiontaking)*actualrate
				,RIGHT(betcheck,len(betcheck)-1)
				,modds
			FROM bodb02.dbo.bettrans14 WITH(NOLOCK)
			WHERE custid = @custid
				AND matchid = 9 
				AND bettype = 9
				AND winlostdate BETWEEN @f_date AND @t_date
				AND statusid IN (112,113)				
	END
	
	SELECT * FROM @tmpBettrans
	WHERE sporttype = ISNULL(@sporttype,sporttype)
	ORDER BY transid DESC
	
GO
GRANT EXECUTE ON [dbo].[RMS_Rpt_Parlay_TopWinners_Details] TO [bodbRMSNet]
 