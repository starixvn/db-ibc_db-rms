/*<info serverAlias="DBRMS-bodb_RMS" executers="bodbRMSNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[RMS_Monitor_ComboParlay_PotentialWinning]
	@selection		VARCHAR(100) = '',
	@sporttype		VARCHAR(100) = '',
	@level			VARCHAR(100) = '',
	@WinningAmount	MONEY= 0,
	@limitRowCount	INT = 100,
	@ParlayType		VARCHAR(10)  = ''
 AS
	/*
		Created: Winnie
		Date: 2016-04-27
		Task: Monitoring Total Potential Winning by member
		DB: DBRMS/bodb_RMS
		
		Revisions:
			-20170719@Winnie: Add MuayThai RedmineID: #79500
			-20171219@Vicky: Add column currency [RedmineID: #88400]
			-20190214@Jacob: Add Bet Builder RedmineID: #108694
		Parameter's Explanation:
			- @selection:- '2,3': 2,3 selections
						 - '10': 10 UP
			- @sporttype:= '1' : soccer only
						= '2' : Other sports
						= '3' : combined sports
			- @level:= '0': none
					 = '1,2,3': level 1,2,3
			 - @ParlayType = 1: Mix parlay
							2: Combo parlay
							3: Single Match Parlay
		
	*/
BEGIN
	SET NOCOUNT ON 
	DECLARE @tmpSelection TABLE (selection int)
	DECLARE @tmpSport TABLE (sporttype int)	
	DECLARE @tmpLevel TABLE (level int)	
	DECLARE @MinTransID BIGINT
	CREATE TABLE #bettransm(refno BIGINT, transid BIGINT)
	DECLARE @10up varchar(500)
	DECLARE @all varchar(500)
	
	 DECLARE @IsMixParlay BIT = 0, @IsComboParlay BIT = 0, @IsSingleMatchParlay BIT = 0
	SELECT  @IsMixParlay = CASE WHEN CHARINDEX('1', @ParlayType) > 0 THEN 1 ELSE 0 END,
		   @IsComboParlay = CASE WHEN CHARINDEX('2', @ParlayType) > 0 THEN 1 ELSE 0 END,
		   @IsSingleMatchParlay = CASE WHEN CHARINDEX('3', @ParlayType) > 0 THEN 1 ELSE 0 END
	
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
	

	INSERT INTO @tmpSport (sporttype)
	SELECT val
	FROM f_RMS_strSplit (@sporttype,',')
	
	IF EXISTS (SELECT TOP 1 1 FROM @tmpSport WHERE sporttype=-2)
	BEGIN
	INSERT INTO @tmpSport
	SELECT SportType FROM bodb02.dbo.Sports(NOLOCK) WHERE SportType NOT IN (1,2,3,4,5,6,7,8,9,11,43,44)
	END
	
	INSERT INTO @tmpLevel (level)
	SELECT val
	FROM f_RMS_strSplit (@level,',')
	
	INSERT INTO #bettransm(refno, transid)
	SELECT refno, transid
	FROM rmBettrans b WITH(NOLOCK) 		
	INNER JOIN 	@tmpSelection c ON b.hdp2=c.selection	
	INNER JOIN  @tmpSport     d ON b.transid2=d.sporttype
	WHERE ( ((@IsMixParlay = 1 OR @IsComboParlay = 1) AND	b.matchid = 29 ) OR (@IsSingleMatchParlay = 1 AND b.bettype = 38))
		AND b.statusid = 0
		AND currency <> 20
		
	
	SELECT @MinTransID = MIN(transid) FROM #bettransm

	IF EXISTS(SELECT TOP 1 1 FROM @tmpLevel WHERE level = 0)
	BEGIN
			SELECT TOP (@limitRowcount)
			transdate,
			custid,
			username,
			odds,
			stake,
			WinningAmount,			
			CompanyLoseAmount,
			TotalBets,
			level,
			currency
		FROM
		(		
	
			SELECT  
				MAX(b.transdate) AS transdate,
				b.custid,
				b.username,				
				AVG(b.odds2*b.TotalBet) AS Odds,
				SUM(b.stake*b.actualrate) AS stake,
				SUM((b.odds2-1)*b.stake*b.actualrate) as WinningAmount,		
				SUM((b.odds2-1)*b.stake*b.actualrate*(1-b.tpositiontaking)) as CompanyLoseAmount,	
				COUNT(1) AS TotalBets,				
				ISNULL(mc.level,0) AS level,
				b.CurrencyName as currency
			FROM rmBettrans b WITH(NOLOCK) 
				INNER JOIN #bettransm bm ON b.transid = bm.transid
				LEFT JOIN rmCustomer mc WITH(NOLOCK) ON b.custid = mc.custid AND level IN (SELECT [level] FROM @tmpLevel)
				INNER JOIN @tmpSport c ON b.transid2=c.sporttype
			WHERE b.transID >= @MinTransID 
			AND ((@IsMixParlay=1 AND betteam ='1' AND bettype=29 AND matchid IN(9,29) )OR (@IsMixParlay=1 AND bettype=9 AND matchid IN(9,29)) OR (@IsComboParlay= 1 AND bettype=29 AND betteam <>'1' AND matchid IN(9,29)) OR (@IsSingleMatchParlay=1 AND bettype=38))		
			GROUP BY b.custid, b.username, ISNULL(mc.level,0),b.CurrencyName
			
			)r
			WHERE WinningAmount >= @WinningAmount
			ORDER BY WinningAmount DESC

	END
	ELSE
	BEGIN
			SELECT top (@limitRowCount)
			transdate,
			custid, 
			username,
			odds,
			stake,
			WinningAmount,			
			CompanyLoseAmount,
			TotalBets,
			level,
			currency
			FROM 
			(
			
			SELECT 
				MAX(b.transdate) AS transdate,
				b.custid,
				b.username,
				AVG(b.odds2*b.TotalBet) AS Odds,
				SUM(b.stake*b.actualrate) AS stake,
				SUM((b.odds2-1)*b.stake*b.actualrate) AS WinningAmount,		
				SUM((b.odds2-1)*b.stake*b.actualrate*(1-b.tpositiontaking)) AS CompanyLoseAmount,	
				COUNT(1) AS TotalBets,				
				ISNULL(mc.level,0) AS level,
				b.CurrencyName as currency
			FROM rmCustomer mc WITH(NOLOCK) 			
				INNER JOIN rmBettrans b WITH(NOLOCK) ON b.custid = mc.custid
				INNER JOIN #bettransm bm ON b.transid = bm.transid
				INNER JOIN @tmpLevel t ON ISNULL(mc.level,0)=t.level
				INNER JOIN @tmpSport c ON b.transid2=c.sporttype
			WHERE	b.transID >= @MinTransID  
			AND ((@IsMixParlay=1 AND betteam ='1' AND bettype=29 AND matchid IN(9,29) )OR (@IsMixParlay=1 AND bettype=9 AND matchid IN(9,29)) OR (@IsComboParlay= 1 AND bettype=29 AND betteam <>'1' AND matchid IN(9,29)) OR (@IsSingleMatchParlay=1 AND bettype=38))		
			GROUP BY b.custid, b.username, ISNULL(mc.level,0),b.CurrencyName
			
			)
			 r
		WHERE WinningAmount >= @WinningAmount 
		ORDER BY WinningAmount DESC
	
	END		
END

GO
