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
		Parameter's Explanation:
			- @selection:- '2,3': 2,3 selections
						 - '10': 10 UP
			- @sporttype:= '1' : soccer only
						= '2' : Other sports
						= '3' : combined sports
			- @level:= '0': none
					 = '1,2,3': level 1,2,3
		
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
	WHERE	b.matchid = 29
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
			level
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
				ISNULL(mc.level,0) AS level
			FROM rmBettrans b WITH(NOLOCK) 
				INNER JOIN #bettransm bm ON b.transid = bm.transid
				LEFT JOIN rmCustomer mc WITH(NOLOCK) ON b.custid = mc.custid AND level IN (SELECT [level] FROM @tmpLevel)
				INNER JOIN @tmpSport c ON b.transid2=c.sporttype
			WHERE b.transID >= @MinTransID 
			AND (@_parlayType=0 OR (@_parlayType=1 AND betteam ='1' ) OR (@_parlayType=2 AND betteam <>'1' ))
			GROUP BY b.custid, b.username, ISNULL(mc.level,0)			
			
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
			level
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
				ISNULL(mc.level,0) AS level
			FROM rmCustomer mc WITH(NOLOCK) 			
				INNER JOIN rmBettrans b WITH(NOLOCK) ON b.custid = mc.custid
				INNER JOIN #bettransm bm ON b.transid = bm.transid
				INNER JOIN @tmpLevel t ON ISNULL(mc.level,0)=t.level
				INNER JOIN @tmpSport c ON b.transid2=c.sporttype
			WHERE	b.transID >= @MinTransID  
			AND (@_parlayType=0 OR (@_parlayType=1 AND betteam ='1' ) OR (@_parlayType=2 AND betteam <>'1' ))
			GROUP BY b.custid, b.username, ISNULL(mc.level,0)	
			
			)
			 r
		WHERE WinningAmount >= @WinningAmount 
		ORDER BY WinningAmount DESC
	
	END		
END

GO
GRANT EXECUTE ON [dbo].[RMS_Monitor_ComboParlay_PotentialWinning] TO [bodbRMSNet]
GO
GRANT VIEW DEFINITION ON [dbo].[RMS_Monitor_ComboParlay_PotentialWinning] TO [vnteam]	


