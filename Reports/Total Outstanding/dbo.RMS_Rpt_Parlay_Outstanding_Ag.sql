 ALTER PROCEDURE [dbo].[RMS_Rpt_Parlay_Outstanding_Ag]
	@custid		INT,	
	@selection	VARCHAR(100) = '',
	@sporttype	VARCHAR(100) = ''
AS
	/*
		Created: Johnson
		Date: 2013-05-14
		Task: Get parlay betlist running by agent
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
	
	SELECT *
	FROM (					
		SELECT custid,
			username,
			SUM(stake*actualrate*(1-tpositiontaking)) as stakePT,
			SUM(stake*actualrate*(odds-1)*(1-tpositiontaking)) as net_win,
			COUNT(1) as betcount
		FROM rmBettrans WITH(NOLOCK)
		WHERE recommend = @custid
			AND matchid = 9
			AND statusid = 0		
			AND liveawayscore IN (SELECT sporttype FROM @tmpSport)
			AND right(betcheck,len(betcheck)-1) IN (SELECT selection FROM @tmpSelection)
		GROUP BY custid,username
		) r
	ORDER  BY net_win DESC 

GO
GRANT EXECUTE ON [dbo].[RMS_Rpt_Parlay_Outstanding_Ag] TO [bodbRMSNet]