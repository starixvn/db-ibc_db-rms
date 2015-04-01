ALTER PROCEDURE [dbo].[RMS_Rpt_Parlay_Outstanding_Mem]
	@custid		INT,	
	@selection	VARCHAR(100) = '',
	@sporttype	VARCHAR(100) = ''
AS
	/*
		Created: Johnson
		Date: 2013-05-14
		Task: Get parlay betlist running by member
		DB: DBRMS/bodb_RMS
		
		Revisions:
			- 20150404@Elodie: change Net Win after PT instead of Max Pay Out after PT
		Parameter's Explanation:	
			-@sporttype = 0 : all sports
						= 1 : soccer only
						= 2 : Other sports
						= 3 : combined sports
	*/ 
SET NOCOUNT ON
	DECLARE @tmpSelection TABLE (selection int)
	DECLARE @tmpSport TABLE (sporttype int)
	DECLARE @6up varchar(100)
	
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
	
	SELECT transid,
		refno,
		transdate,
		stake,
		stakePT,
		net_win,
		odds,
		combo
	FROM (		
		SELECT transid,
			refno,
			transdate,
			odds,
			stake*actualrate stake,
			stake*actualrate*(1-tpositiontaking) stakePT,
			stake*actualrate*(odds-1)*(1-tpositiontaking) net_win,
			right(betcheck,len(betcheck)-1) combo,
			liveawayscore as sporttype			
		FROM rmBettrans WITH(NOLOCK)
		WHERE custid = @custid 
			AND matchid = 9
			AND statusid = 0			
	)r 
	WHERE sporttype IN (SELECT sporttype FROM @tmpSport)
		AND combo IN (SELECT selection FROM @tmpSelection)
	ORDER BY net_win DESC
	
GO
GRANT EXECUTE ON [dbo].[RMS_Rpt_Parlay_Outstanding_Mem] TO [bodbRMSNet]