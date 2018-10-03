/*<info serverAlias="DBRMS-bodb_RMS" executers="bodbRMSNet" viewers="" isFunction="0" isNested="0"></info>*/

 ALTER PROCEDURE [dbo].[RMS_Rpt_ComboParlay_Winloss_Mem]
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
		Date: 20151205
		DB: DBRMS/bodb_RMS
		Task: Get report win loss by specific member
		
		Revisions:
				- 20170719@Winnie: Add MuayThai RedmineID: #79500	
				- 20180927@Jacob: Apply Extra PT and Super Comm to Report.  RedmineID: #100951 				
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
	DECLARE @10UP VARCHAR(500),@all varchar(500)
	DECLARE @tmpParlayType TABLE (parlaytype tinyint)
	DECLARE @_ParlayType	TINYINT
	DECLARE @tmpSport TABLE (sporttype int)
	
	
	INSERT INTO @tmpSport (sporttype)
	SELECT val
	FROM f_RMS_strSplit (@sporttype,',')
	IF EXISTS (SELECT TOP 1 1 FROM @tmpSport WHERE sporttype=-2)
	BEGIN
	INSERT INTO @tmpSport
	SELECT SportType FROM bodb02.dbo.Sports(NOLOCK) WHERE SportType NOT IN (1,2,3,4,5,6,7,8,9,11,43,44)
	END

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
		 INNER JOIN @tmpSelection b ON CASE WHEN bettype=9 THEN right(betcheck,len(betcheck)-1) ELSE hdp2 END =b.selection
		 INNER JOIN @tmpSport c ON transid2=c.sporttype
		 LEFT JOIN bodb02.dbo.Acc_GroupExtraPTSetting AS a WITH (NOLOCK) ON srecommend = a.SuperId
                                                                        AND winlostdate BETWEEN a.FromDate AND a.Todate
														  AND a.ProductID = 1
														  AND a.Sporttype = 0
														  AND a.SubProduct = ''
		 WHERE custid = @custid 
			AND winlostdate BETWEEN @f_date AND @t_date
			AND matchid IN(9,29) 
			AND statusid IN (112,113)			
			AND (@_parlayType=0 OR (@_parlayType=1  AND bettype=29 AND betteam ='1')OR (@_parlayType=1 AND bettype=9) OR (@_parlayType=2 AND bettype=29 AND betteam <>'1' ))	
			
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
				convert(varchar(7),a.winlostdate,120)
				,sum(case when a.statusid = 112 then betcount else 0 end) as tickets_won
				,sum(case when a.statusid = 113 then betcount else 0 end) as tickets_lose
				,sum(case when a.statusid = 112 then company_stake*actualrate - ISNULL(e.stake, 0) * actualrate else 0 end) as stake_won
				,sum(case when a.statusid = 113 then company_stake*actualrate - ISNULL(e.stake, 0) * actualrate else 0 end) as stake_lose
				,sum(case when a.statusid = 112 then -(a.winlost-a.stake)*actualrate else 0 end) as member_won
				,sum(case when a.statusid = 113 then -(a.winlost-a.stake)*actualrate else 0 end) as member_lose
				,sum(case when a.statusid = 112 then (company_winlost - ISNULL(e.winlost, 0) - ISNULL(e.scomm, 0) + ISNULL(e.comm, 0)) *actualrate else 0 end) as ourPT_won
				,sum(case when a.statusid = 113 then (company_winlost- ISNULL(e.winlost, 0) - ISNULL(e.scomm, 0) + ISNULL(e.comm, 0)) *actualrate else 0 end) as ourPT_lose		
			FROM rmSumWinloss a WITH(NOLOCK)
			INNER JOIN @tmpSelection b ON a.combo=b.selection
			INNER JOIN @tmpSport c ON a.sporttype=c.sporttype
			LEFT JOIN rmSumWinLossExtraPT e WITH(NOLOCK) ON a.[custid] = e.[custid] AND a.[winlostdate] = e.[winlostdate] AND a.[sporttype] = e.[sporttype] AND a.[statusid] = e.[statusid] AND a.[combo] = e.[combo]
			WHERE a.custid = @custid
					AND a.winlostdate BETWEEN @f_date AND @t_date				
					AND a.statusid IN (112,113)
					AND currency <> 20					
					AND (@_parlayType=0 OR (@_parlayType=1 AND ISNULL(a.parlaytype,1) IN(1,2)) OR (@_parlayType=2 AND ISNULL(a.parlaytype,1) =3))					
			GROUP BY convert(varchar(7),a.winlostdate,120)
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
				convert(varchar(7),a.winlostdate,120)
				,sum(case when a.statusid = 112 then betcount else 0 end) as tickets_won
				,sum(case when a.statusid = 113 then betcount else 0 end) as tickets_lose
				,sum(case when a.statusid = 112 then company_stake*actualrate - ISNULL(e.stake, 0) * actualrate else 0 end) as stake_won
				,sum(case when a.statusid = 113 then company_stake*actualrate - ISNULL(e.stake, 0) * actualrate else 0 end) as stake_lose
				,sum(case when a.statusid = 112 then -(a.winlost-a.stake)*actualrate else 0 end) as member_won
				,sum(case when a.statusid = 113 then -(a.winlost-a.stake)*actualrate else 0 end) as member_lose
				,sum(case when a.statusid = 112 then (company_winlost - ISNULL(e.winlost, 0) - ISNULL(e.scomm, 0) + ISNULL(e.comm, 0)) *actualrate else 0 end) as ourPT_won
				,sum(case when a.statusid = 113 then (company_winlost- ISNULL(e.winlost, 0) - ISNULL(e.scomm, 0) + ISNULL(e.comm, 0)) *actualrate else 0 end) as ourPT_lose	
			FROM rmSumWinloss_Old a WITH(NOLOCK)
			INNER JOIN @tmpSelection b ON a.combo=b.selection
			INNER JOIN @tmpSport c ON a.sporttype=c.sporttype
			LEFT JOIN rmSumWinlossExtraPT_Old e WITH(NOLOCK) ON a.[custid] = e.[custid] AND a.[winlostdate] = e.[winlostdate] AND a.[sporttype] = e.[sporttype] AND a.[statusid] = e.[statusid] AND a.[combo] = e.[combo]
			WHERE a.custid = @custid
					AND a.winlostdate BETWEEN @f_date AND @t_date				
					AND a.statusid IN (112,113)
					AND currency <> 20					
					AND (@_parlayType=0 OR (@_parlayType=1 AND ISNULL(a.parlaytype,1)  IN(1,2)) OR (@_parlayType=2 AND ISNULL(a.parlaytype,1) =3))	
			GROUP BY convert(varchar(7),a.winlostdate,120)
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
GRANT EXECUTE ON [dbo].[RMS_Rpt_ComboParlay_Winloss_Mem] TO [bodbRMSNet]		