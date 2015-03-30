ALTER PROCEDURE [dbo].[RMS_Monitor_Parlay_PotentialWinning]
	@selection		VARCHAR(100) = '',
	@sporttype		VARCHAR(100) = '',
	@level			VARCHAR(100) = '',
	@WinningAmount	MONEY= 0,
	@limitRowCount	INT = 100
 AS
	/*
		Created: Elodie
		Date: 2015-03-24
		Task: Monitoring Total Potential Winning by member
		DB: DBRMS/bodb_RMS
		
		Revisions:
			
		Parameter's Explanation:
			- @selection:- '2,3': 2,3 selections
						 - '6': 6 UP
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
	DECLARE @6up varchar(100)
	DECLARE @MinTransID BIGINT
	CREATE TABLE #bettransm(refno BIGINT, transid BIGINT)
	
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

	INSERT INTO @tmpSport (sporttype)
	SELECT val
	FROM f_RMS_strSplit (@sporttype,',')
	
	INSERT INTO @tmpLevel (level)
	SELECT val
	FROM f_RMS_strSplit (@level,',')
	
	INSERT INTO #bettransm(refno, transid)
	SELECT refno, transid
	FROM rmBettrans b WITH(NOLOCK) 				
	WHERE b.combo IN (SELECT selection FROM @tmpSelection)
		AND b.matchid = 9
		AND b.statusid = 0
		AND currency <> 20
		AND b.liveawayscore IN (SELECT sporttype FROM @tmpSport)	
	
	SELECT @MinTransID = MIN(transid) FROM #bettransm

	IF EXISTS(SELECT 1 FROM @tmpLevel WHERE level = 0)
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
				AVG(b.odds) AS Odds,
				SUM(b.stake*b.actualrate) AS stake,
				SUM((b.odds-1)*b.stake*b.actualrate) as WinningAmount,		
				SUM((b.odds-1)*b.stake*b.actualrate*(1-b.tpositiontaking)) as CompanyLoseAmount,	
				COUNT(1) AS TotalBets,				
				ISNULL(mc.level,0) AS level
			FROM rmBettrans b WITH(NOLOCK) 
				INNER JOIN #bettransm bm ON b.transid = bm.transid
				LEFT JOIN rmCustomer mc WITH(NOLOCK) ON b.custid = mc.custid AND level IN (SELECT [level] FROM @tmpLevel)
			WHERE b.transID > @MinTransID
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
				AVG(b.odds) AS Odds,
				SUM(b.stake*b.actualrate) AS stake,
				SUM((b.odds-1)*b.stake*b.actualrate) AS WinningAmount,		
				SUM((b.odds-1)*b.stake*b.actualrate*(1-b.tpositiontaking)) AS CompanyLoseAmount,	
				COUNT(1) AS TotalBets,				
				ISNULL(mc.level,0) AS level
			FROM rmCustomer mc WITH(NOLOCK) 			
				INNER JOIN rmBettrans b WITH(NOLOCK) ON b.custid = mc.custid
				INNER JOIN #bettransm bm ON b.transid = bm.transid
			WHERE [level] IN (SELECT [level] FROM @tmpLevel)		
				AND b.transID > @MinTransID
			GROUP BY b.custid, b.username, ISNULL(mc.level,0)	
		) r
		WHERE WinningAmount >= @WinningAmount 
		ORDER BY WinningAmount DESC
	END		
END

GO
GRANT EXECUTE ON [dbo].[RMS_Monitor_Parlay_PotentialWinning] TO [bodbRMSNet]
GO
GRANT VIEW DEFINITION ON [dbo].[RMS_Monitor_Parlay_PotentialWinning] TO [vnteam]	


