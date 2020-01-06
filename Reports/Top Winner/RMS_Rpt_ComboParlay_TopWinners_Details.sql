/*<info serverAlias="DBRMS-bodb_RMS" executers="bodbRMSNet" viewers="" isFunction="0" isNested="0"></info>*/

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
		- 20160921@Winnie: Fix bug wrong bettype and fix ticket bettype 29 old format and conflict refno with racing RedmineID: #64286
		- 20170719@Winnie: Add MuayThai RedmineID: #79500
		- 20180927@Jacob: Apply Extra PT and Super Comm to Report.  RedmineID: #100951 		
		- 20190214@Jacob: Add Bet Builder RedmineID: #108694
		- 20191211@Jacob: Extra PT - Add new structure to support extra pt column on bettrans table #124194
		Parameter's Explanation:
		- @ParlayType = 1: Mix parlay
							2: Combo parlay
							3: Single Match Parlay
	*/
SET NOCOUNT ON
	DECLARE @f_date DATETIME,
			@t_date DATETIME			
	DECLARE @tmpBettrans TABLE (transid BIGINT PRIMARY KEY
				,refno BIGINT
				,sporttype SMALLINT
				,bettype INT
				,stake MONEY
				,winlost MONEY
				,company_winlost MONEY
				,stake_baseRM MONEY
				,winlost_baseRM MONEY
				,company_winlost_baseRM MONEY
				,combo TINYINT			
				,IsMixParlay BIT
				,IsSingleMatchParlay BIT
				,TotalCombo BIGINT
			)
		DECLARE @tmpBettrans2 TABLE (transid BIGINT PRIMARY KEY		
				,hdp2       INT
				,betteam	BIGINT
				,refno		BIGINT		
			)
			
	CREATE TABLE #tmpbettransm(	
	refno BIGINT NOT NULL,
	sporttype INT NULL)	
	
	CREATE CLUSTERED INDEX [IX_refno] ON [dbo].#tmpbettransm 
	(
		[refno] ASC
	)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
	
	DECLARE @tmpSelection TABLE(selection tinyint)	
	DECLARE @10up varchar(500),@all varchar(500)
	DECLARE @tmpSport TABLE (sporttype int)	

	 DECLARE @IsMixParlay BIT = 0, @IsComboParlay BIT = 0, @IsSingleMatchParlay BIT = 0
	SELECT  @IsMixParlay = CASE WHEN CHARINDEX('1', @ParlayType) > 0 THEN 1 ELSE 0 END,
		   @IsComboParlay = CASE WHEN CHARINDEX('2', @ParlayType) > 0 THEN 1 ELSE 0 END,
		   @IsSingleMatchParlay = CASE WHEN CHARINDEX('3', @ParlayType) > 0 THEN 1 ELSE 0 END

	
	INSERT INTO @tmpSelection
	SELECT val
	FROM f_RMS_strSplit (@selection,',')
	
	INSERT INTO @tmpSport (sporttype)
	SELECT val
	FROM f_RMS_strSplit (@sporttype,',')
	IF EXISTS (SELECT TOP 1 1 FROM @tmpSport WHERE sporttype=-2)
	BEGIN
	INSERT INTO @tmpSport
	SELECT SportType FROM bodb02.dbo.Sports(NOLOCK) WHERE SportType NOT IN (1,2,3,4,5,6,7,8,9,11,43,44)
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
		SELECT @f_date = CASE WHEN @fromdate > @movebetsday THEN @fromdate ELSE dateadd(dd,1,@movebetsday) END,
				@t_date = @todate
		
		INSERT INTO @tmpBettrans (transid
				,refno
				,sporttype
				,bettype
				,stake
				,winlost
				,company_winlost
				,stake_baseRM
				,winlost_baseRM
				,company_winlost_baseRM
				,combo				
				,IsMixParlay
				,IsSingleMatchParlay
				,TotalCombo)
		SELECT transid
			,refno
			,transid2
			,bettype
			,stake
			,winlost-actual_stake
			,-(winlost - actual_stake)  * (1 - tpositiontaking - CAST(ISNULL(epositiontaking,0) AS DECIMAL(9,8))) - scomm  + scomm * CAST(ISNULL(epositiontaking,0) AS DECIMAL(9,8)) / (1 - tpositiontaking)
			,stake*actualrate
			,(winlost-actual_stake)*actualrate
			,(-(winlost - actual_stake)  * (1 - tpositiontaking - CAST(ISNULL(epositiontaking,0) AS DECIMAL(9,8))) - scomm  + scomm * CAST(ISNULL(epositiontaking,0) AS DECIMAL(9,8)) / (1 - tpositiontaking) ) * actualrate
			,hdp2 AS combo		
			,CASE WHEN bettype=29 AND betteam='1' THEN 1 ELSE 0 END AS IsMixParlay
			,CASE WHEN bettype=38 THEN 1 ELSE 0 END
			,TotalBet AS TotalCombo
		FROM rmBettrans WITH(NOLOCK)
		WHERE custid = @custid
			AND ( ((@IsMixParlay = 1 OR @IsComboParlay = 1 ) AND matchid = 29) OR @IsSingleMatchParlay = 1 AND bettype = 38)
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
				,bettype
				,stake
				,winlost
				,company_winlost
				,stake_baseRM
				,winlost_baseRM
				,company_winlost_baseRM
				,combo
				,IsMixParlay
				,IsSingleMatchParlay
				,TotalCombo
				)
			SELECT transid
				,refno
				,liveawayscore
				,bettype
				,stake
				,winlost-actual_stake
				,-(winlost - actual_stake)  * (1 - tpositiontaking - CAST(ISNULL(epositiontaking,0) AS DECIMAL(9,8))) - scomm  + scomm * CAST(ISNULL(epositiontaking,0) AS DECIMAL(9,8)) / (1 - tpositiontaking)
				,stake*actualrate
				,(winlost-actual_stake)*actualrate
				,(-(winlost - actual_stake)  * (1 - tpositiontaking - CAST(ISNULL(epositiontaking,0) AS DECIMAL(9,8))) - scomm  + scomm * CAST(ISNULL(epositiontaking,0) AS DECIMAL(9,8)) / (1 - tpositiontaking) ) * actualrate
				,hdp2
				,CASE WHEN bettype=29 AND betteam='1' THEN 1 ELSE 0 END AS IsMixParlay
				,CASE WHEN bettype=38 THEN 1 ELSE 0 END
				,CASE WHEN bettype=38 THEN 1 ELSE 0 END AS TotalCombo
			FROM bodb02.dbo.bettrans14 WITH(NOLOCK)
			WHERE custid = @custid
				AND ( ((@IsMixParlay = 1 OR @IsComboParlay = 1 ) AND matchid = 29 AND bettype = 29) OR @IsSingleMatchParlay = 1 AND bettype = 38)				
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
				AND bettype = 29
				AND winlostdate BETWEEN @f_date AND @t_date
				AND statusid IN (112,113)					
		;WITH ParlayTotalBet AS(
		SELECT TransID, SUM (rcs.cnt) AS TotalCombo
		FROM @tmpBettrans2 b
			INNER JOIN bodb02.dbo.RefCombinationSet rcs WITH(NOLOCK) ON b.hdp2 = rcs.N
		WHERE  (b.betteam & rcs.bitmapR) > 0
		GROUP BY b.transid
		)
		UPDATE b
		SET b.TotalCombo = pt.TotalCombo
		FROM @tmpBettrans b 
		INNER JOIN ParlayTotalBet pt ON b.TransID = pt.TransID	
		
		INSERT INTO #tmpbettransm(	refno ,	sporttype)
		SELECT a.refno,m.sporttype 
		FROM @tmpBettrans b 
		INNER JOIN DBARC.bodb_Archive.dbo.bettransm a(NOLOCK) ON a.refno=b.refno
		INNER JOIN DBARC.bodb_Archive.dbo.match_bk m(NOLOCK) ON a.matchid=m.matchid	
		WHERE m.sporttype<=99 AND b.bettype = 29
		
		INSERT INTO #tmpbettransm(	refno ,	sporttype)
		SELECT a.refno,m.sporttype 
		FROM @tmpBettrans b 
		INNER JOIN bodb02.dbo.bettransm a(NOLOCK) ON a.refno=b.refno
		INNER JOIN bodb02.dbo.match m(NOLOCK) ON a.matchid=m.matchid	
		WHERE m.sporttype<=99 AND b.bettype = 29
		
		INSERT INTO #tmpbettransm(	refno ,	sporttype)
		SELECT a.refno,m.sporttype 
		FROM @tmpBettrans b 
		INNER JOIN bodb02.dbo.bettransm14 a(NOLOCK) ON a.refno=b.refno
		INNER JOIN bodb02.dbo.match14 m(NOLOCK) ON a.matchid=m.matchid	
		WHERE m.sporttype<=99 AND b.bettype = 29
		
		-- Join Bettransm to get sporttype(transid2) for bettype = 29
		UPDATE bb
		SET bb.sporttype = aa.transid2
		FROM @tmpBettrans  bb INNER JOIN 
		(SELECT b.refno,
		CASE WHEN COUNT(DISTINCT(sporttype))=1 THEN MIN(sporttype)
		WHEN COUNT(DISTINCT(sporttype))<>1 AND MIN(sporttype)=1 THEN  -3
		ELSE -1
		END AS transid2
		FROM #tmpbettransm b 		
		GROUP BY b.refno) aa ON aa.refno=bb.refno
		
		-- sporttype(transid2) always is 1 for bettype = 38
		UPDATE @tmpBettrans SET sporttype = 1
	     WHERE bettype = 38
	END
	
	SELECT a.* FROM @tmpBettrans a
	INNER JOIN @tmpSelection b ON a.combo=b.selection
	INNER JOIN @tmpSport c ON a.sporttype=c.sporttype
	WHERE (@IsMixParlay=1 AND a.IsMixParlay=1) OR (@IsComboParlay=1 AND a.IsMixParlay<>1 ) OR (@IsSingleMatchParlay=1 AND IsSingleMatchParlay=1)		
	
	ORDER BY transid DESC
	
    DROP TABLE #tmpbettransm
    DROP TABLE #ExtraPT_Sel;
GO