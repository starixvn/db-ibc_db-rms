ALTER PROCEDURE [dbo].[RMS_Rpt_ComboParlay_TopWinners_Details]
	@custid			INT,
	@fromdate		DATETIME,
	@todate			DATETIME,
	@sporttype		VARCHAR(100)='',
	@movebetsday	DATETIME,
	@selection		VARCHAR(100) = '',
	@ParlayType		VARCHAR(10)=''
AS
	/*
		Created: Winnie
		Date: 2015-05-11
		DB: DBRMS/bodb_RMS
		Task: Combo Parlay bet list for top winners
		
		Revisions:
		Parameter's Explanation:
	*/
SET NOCOUNT ON
	DECLARE @f_date DATETIME,
			@t_date DATETIME			
	DECLARE @tmpBettrans TABLE (transid BIGINT PRIMARY KEY
				,refno BIGINT
				,sporttype SMALLINT
				,stake MONEY
				,winlost MONEY
				,company_winlost MONEY
				,stake_baseRM MONEY
				,winlost_baseRM MONEY
				,company_winlost_baseRM MONEY
				,combo TINYINT			
				,IsMixParlay BIT
				,TotalCombo BIGINT
			)
		DECLARE @tmpBettrans2 TABLE (transid BIGINT PRIMARY KEY		
				,hdp2       INT
				,betteam	BIGINT
				,refno		BIGINT		
			)
	
	DECLARE @tmpSelection TABLE(selection tinyint)	
	DECLARE @10up varchar(500),@all varchar(500)
	DECLARE @tmpParlayType TABLE (parlaytype tinyint)
	DECLARE @_ParlayType	TINYINT
	DECLARE @tmpSport TABLE (sporttype int)	

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
		SELECT @f_date = CASE WHEN @fromdate > @movebetsday THEN @fromdate ELSE dateadd(dd,1,@movebetsday) END,
				@t_date = @todate
		
		INSERT INTO @tmpBettrans (transid
				,refno
				,sporttype
				,stake
				,winlost
				,company_winlost
				,stake_baseRM
				,winlost_baseRM
				,company_winlost_baseRM
				,combo				
				,IsMixParlay
				,TotalCombo)
		SELECT transid
			,refno
			,transid2
			,stake
			,winlost-actual_stake
			,-(winlost-actual_stake)*(1-tpositiontaking) as company_winlost
			,stake*actualrate
			,(winlost-actual_stake)*actualrate
			,-(winlost-actual_stake)*(1-tpositiontaking)*actualrate as company_winlost_baseRM
			,CASE WHEN bettype=9 THEN RIGHT(betcheck,len(betcheck)-1) ELSE hdp2 END AS combo		
			,CASE WHEN bettype=9 OR betteam='1' THEN 1 ELSE 0 END AS IsMixParlay
			,CASE WHEN bettype=9 THEN 1 ELSE TotalBet END AS TotalCombo
		FROM rmBettrans WITH(NOLOCK)
		WHERE custid = @custid
			AND matchid IN(9,29)
			AND winlostdate BETWEEN @f_date AND @t_date
			AND statusid IN (112,113)

	END
	IF @fromdate <= @movebetsday
	BEGIN
		SELECT @f_date = @fromdate, 
			@t_date = CASE WHEN @todate > @MoveBetsDay THEN @MoveBetsDay ELSE @todate END
					
			INSERT INTO @tmpBettrans (transid
				,refno
				,sporttype
				,stake
				,winlost
				,company_winlost
				,stake_baseRM
				,winlost_baseRM
				,company_winlost_baseRM
				,combo
				,IsMixParlay
				,TotalCombo
				)
			SELECT transid
				,refno
				,liveawayscore
				,stake
				,winlost-actual_stake
				,-(winlost-actual_stake)*(1-tpositiontaking)
				,stake*actualrate
				,(winlost-actual_stake)*actualrate
				,-(winlost-actual_stake)*(1-tpositiontaking)*actualrate
				,CASE WHEN bettype=9 THEN RIGHT(betcheck,len(betcheck)-1) ELSE hdp2 END AS combo
				,CASE WHEN bettype=9 OR betteam='1' THEN 1 ELSE 0 END AS IsMixParlay
				,CASE WHEN bettype=9 THEN 1 ELSE NULL END AS TotalCombo
			FROM bodb02.dbo.bettrans14 WITH(NOLOCK)
			WHERE custid = @custid
				AND matchid IN(9,29) 
				AND bettype IN(9,29)
				AND winlostdate BETWEEN @f_date AND @t_date
				AND statusid IN (112,113)		

		INSERT INTO @tmpBettrans2 (transid
				,hdp2    
				,betteam	
				,refno				
				)
			SELECT transid
				,hdp2
				,betteam
				,refno				
			FROM bodb02.dbo.bettrans14 WITH(NOLOCK)
			WHERE custid = @custid				
				AND bettype =29 AND betcheck IS NOT NULL
				AND winlostdate BETWEEN @f_date AND @t_date
				AND statusid IN (112,113)					
		;WITH ParlayTotalBet AS(
		SELECT TransID, SUM (rcs.cnt) AS TotalCombo
		FROM @tmpBettrans2 b
			INNER JOIN bodb02.dbo.RefCombinationSet_xtest rcs WITH(NOLOCK) ON b.hdp2 = rcs.N
		WHERE  (b.betteam & rcs.bitmapR) > 0
		GROUP BY b.transid
		)
		UPDATE b
		SET b.TotalCombo = pt.TotalCombo
		FROM @tmpBettrans b 
		INNER JOIN ParlayTotalBet pt ON b.TransID = pt.TransID	
		
		UPDATE bb
		SET bb.sporttype = aa.transid2
		FROM @tmpBettrans  bb INNER JOIN 
		(SELECT b.refno,
		CASE WHEN COUNT(DISTINCT(sporttype))=1 THEN MIN(sporttype)
		WHEN COUNT(DISTINCT(sporttype))<>1 AND MIN(sporttype)=1 THEN  -3
		ELSE -1
		END AS transid2
		FROM @tmpBettrans2 b 
		INNER JOIN bodb02.dbo.bettransm a(NOLOCK) ON a.refno=b.refno
		INNER JOIN bodb02.dbo.match c(NOLOCK) ON a.matchid=c.matchid	
		GROUP BY b.refno) aa ON aa.refno=bb.refno
		
	END
	
	SELECT a.* FROM @tmpBettrans a
	INNER JOIN @tmpSelection b ON a.combo=b.selection
	INNER JOIN @tmpSport c ON a.sporttype=c.sporttype
	WHERE (@_parlayType=0 OR (@_parlayType=1 AND a.IsMixParlay=1) OR (@_parlayType=2 AND a.IsMixParlay<>1))	
	ORDER BY transid DESC
	

GO
GRANT EXECUTE ON [dbo].[RMS_Rpt_ComboParlay_TopWinners_Details] TO [bodbRMSNet]
 