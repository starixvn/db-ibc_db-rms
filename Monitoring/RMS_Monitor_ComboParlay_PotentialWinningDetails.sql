 ALTER PROCEDURE [dbo].[RMS_Monitor_ComboParlay_PotentialWinningDetails]
	@CustID			INT,
	@selection		VARCHAR(100) = '',
	@sporttype		VARCHAR(100) = '',
	@ParlayType		VARCHAR(10)  = ''
 AS
	/*	
		Created: Winnie
		Date: 2016-04-27
		DB: DBRMS/bodb_RMS
		Task: Get detail report of Potential Winning Tool
		
		Revisions:
		
		Parameter's Explanation:
		
	*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @tmpSport TABLE (sporttype int)	
	DECLARE @10up varchar(500)
	DECLARE @all varchar(500)
	DECLARE @tmpParlayType TABLE (parlaytype tinyint)
	DECLARE @_ParlayType	TINYINT

	CREATE TABLE #tmpSelection	(selection INT PRIMARY KEY)

	INSERT INTO @tmpParlayType
	SELECT val
	FROM f_RMS_strSplit (@ParlayType,',')
	IF EXISTS(SELECT TOP 1 1 FROM @tmpParlayType WHERE parlaytype = 1 ) AND EXISTS(SELECT TOP 1 1 FROM @tmpParlayType WHERE parlaytype = 2)
		SELECT @_ParlayType=0
	ELSE IF EXISTS(SELECT TOP 1 1 FROM @tmpParlayType WHERE parlaytype = 1 )
		SELECT @_ParlayType=1
	ELSE IF EXISTS(SELECT TOP 1 1 FROM @tmpParlayType WHERE parlaytype = 2 )
		SELECT @_ParlayType=2

	
	INSERT INTO #tmpSelection
	SELECT val
	FROM f_RMS_strSplit (@selection,',')
	--Check selection is 10-UP
	IF EXISTS(SELECT TOP 1 1 FROM #tmpSelection WHERE selection = 0)
	BEGIN
		SELECT @all = '2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,64,65,66,67,68,69,70,71,72,73,74,75,76,77,78,79,80,81,82,83,84,85,86,87,88,89,90,91,92,93,94,95,96,97,98,99,100'
		TRUNCATE TABLE #tmpSelection
		INSERT INTO #tmpSelection
		SELECT val
		FROM f_RMS_strSplit (@all,',')		
	END
	ELSE IF EXISTS(SELECT TOP 1 1 FROM #tmpSelection WHERE selection = 10)
	BEGIN
		SELECT @10up = '11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,64,65,66,67,68,69,70,71,72,73,74,75,76,77,78,79,80,81,82,83,84,85,86,87,88,89,90,91,92,93,94,95,96,97,98,99,100'

		INSERT INTO #tmpSelection
		SELECT val
		FROM f_RMS_strSplit (@10up,',')		
	END	

	INSERT INTO @tmpSport (sporttype)
	SELECT val
	FROM f_RMS_strSplit (@sporttype,',')
	IF EXISTS (SELECT TOP 1 1 FROM @tmpSport WHERE sporttype=-2)
	BEGIN
	INSERT INTO @tmpSport
	SELECT SportType FROM bodb02.dbo.Sports(NOLOCK) WHERE SportType NOT IN (1,2,3,4,5,6,7,8,9,11,43)
	END
	
	SELECT	b.transdate,
			b.transid,
			b.refno,
			CASE WHEN transid2 NOT IN (-1,-3,1,2,3,4,5,6,7,8,9,11,43) THEN -2 ELSE transid2 END AS Sporttype,		
			(SELECT COUNT(bm.transid) FROM bodb02.dbo.bettransm bm WITH(NOLOCK) WHERE b.refno = bm.refno AND bm.statusid=112) AS NumberWon,
			b.odds2 *b.TotalBet AS odds,
			b.stake*b.actualrate/b.TotalBet AS Stake,
			(b.odds2-1)*b.stake *b.actualrate AS WinningAmount,
			(b.odds2-1)*b.stake*b.actualrate*(1-b.tpositiontaking) AS CompanyLoseAmount,
			b.ip,
			(1-b.tpositiontaking) AS HousePT, 
			b.hdp2 AS TotalSelection,
			b.TotalBet AS TotalBet		
	FROM rmBettrans b WITH (NOLOCK)	
	INNER JOIN @tmpSport c ON b.transid2=c.sporttype
	INNER JOIN #tmpSelection d ON b.hdp2=d.selection
	WHERE b.custid = @CustID		
		AND b.matchid = 29
		AND b.statusid = 0
		AND currency <> 20	
		AND (@_parlayType=0 OR (@_parlayType=1 AND betteam ='1' ) OR (@_parlayType=2 AND betteam <>'1' ))	
	ORDER BY b.transdate DESC
END

GO
GRANT EXECUTE ON [dbo].[RMS_Monitor_ComboParlay_PotentialWinningDetails] TO [bodbRMSNet]
GO
GRANT VIEW DEFINITION ON [dbo].[RMS_Monitor_ComboParlay_PotentialWinningDetails] TO [vnteam]