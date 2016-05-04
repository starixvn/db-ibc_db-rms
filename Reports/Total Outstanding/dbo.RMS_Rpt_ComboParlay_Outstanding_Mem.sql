ALTER PROCEDURE [dbo].[RMS_Rpt_ComboParlay_Outstanding_Mem]
	@custid		INT,	
	@selection	VARCHAR(100) = '',
	@sporttype	VARCHAR(100) = '',
	@ParlayType	VARCHAR(10)=''
AS
	/*
		Created: Winnie
		Date: 2016-04-26
		Task: Get combo parlay betlist running by member
		DB: DBRMS/bodb_RMS
		
		Revisions:		
		Parameter's Explanation:	
			-@sporttype = 0 : all sports
						= 1 : soccer only
						= 2 : Other sports
						= 3 : combined sports
	*/ 
SET NOCOUNT ON
	DECLARE @tmpSelection TABLE (selection int)
	DECLARE @tmpSport TABLE (sporttype int)
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
	
		
		SELECT transid,
			refno,
			transdate,
			odds2*TotalBet AS odds,
			stake*actualrate/TotalBet stake,
			stake*actualrate*(1-tpositiontaking)/TotalBet stakePT,
			stake*actualrate*(odds2-1)*(1-tpositiontaking) net_win,
			hdp2 AS TotalSelection,
			TotalBet AS TotalBet			
		FROM rmBettrans a WITH(NOLOCK)
		INNER JOIN @tmpSelection b ON a.hdp2=b.selection
		INNER JOIN @tmpSport c ON a.liveawayscore=c.sporttype
		WHERE custid = @custid 
			AND matchid = 29
			AND statusid = 0	
			AND (@_parlayType=0 OR (@_parlayType=1 AND a.betteam<>'a' AND a.betteam<>'h' AND CAST(betteam as int)=1 ) OR (@_parlayType=2 AND a.betteam<>'a' AND a.betteam<>'h' AND CAST(betteam as int)<>1 ))		
		ORDER BY net_win DESC
	
GO
GRANT EXECUTE ON [dbo].[RMS_Rpt_ComboParlay_Outstanding_Mem] TO [bodbRMSNet]