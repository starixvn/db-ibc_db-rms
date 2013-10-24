 ALTER PROCEDURE [dbo].[RMS_Rpt_Parlay_DangerMonitor]
	@AgentIDList VARCHAR(4000) = '',
	@selection  VARCHAR(500),
	@max_transid BIGINT = 0 OUTPUT
AS
/*
	Created: Johnson
	Date: 2013-10-22
	Task: Report monitor danger members under specific agents
	DB: DBRMS/bodb_RMS
	
	Revisions:
	
	Parameter's Explanation:
		- @max_transid: transid max is checked
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @Bettrans TABLE(refno BIGINT PRIMARY KEY)
	DECLARE @tmpSelection TABLE (selection int)
		
	INSERT INTO @tmpSelection
	SELECT val
	FROM f_RMS_strSplit (@selection,',')
	
	--Check selection is 6-UP
	IF EXISTS(SELECT 1 FROM @tmpSelection WHERE selection = 6)
	BEGIN
		DECLARE @6up VARCHAR(500)

		SELECT @6up = '7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30'

		INSERT INTO @tmpSelection
		SELECT val
		FROM f_RMS_strSplit (@6up,',')		
	END
	
	SELECT @max_transid = MAX(transid) FROM rmBettrans WITH(NOLOCK) 
	WHERE matchid = 9
					
	IF @AgentIDList = ''
	BEGIN
		INSERT INTO @Bettrans (refno)
		SELECT refno
		FROM rmBettrans b WITH(NOLOCK)
		WHERE matchid = 9
			AND statusid = 0
			AND currency <> 20
			AND liveawayscore = 1-- hardcode soccer only
			AND right(betcheck,len(betcheck)-1) IN (SELECT selection FROM @tmpSelection)
	END
	ELSE
	BEGIN
		INSERT INTO @Bettrans (refno)
		SELECT refno
		FROM rmBettrans b WITH(NOLOCK)
		WHERE recommend IN (SELECT val FROM f_RMS_strSplit(@AgentIDList,','))
			AND matchid = 9
			AND statusid = 0
			AND currency <> 20
			AND liveawayscore = 1
			AND right(betcheck,len(betcheck)-1) IN (SELECT selection FROM @tmpSelection)
	END	
	
	;WITH T AS(
		SELECT matchid		
			,SUM(CASE when bettype = 1 AND betteam = 'h' THEN 1 ELSE 0 end) as hdp_home
			,SUM(CASE when bettype = 1 AND betteam = 'a' THEN 1 ELSE 0 end) as hdp_away
			,SUM(CASE when bettype = 7 AND betteam = 'h' THEN 1 ELSE 0 end) as hdp_1st_home
			,SUM(CASE when bettype = 7 AND betteam = 'a' THEN 1 ELSE 0 end) as hdp_1st_away
			,SUM(CASE when bettype = 3 AND betteam = 'h' THEN 1 ELSE 0 end) as ou_home
			,SUM(CASE when bettype = 3 AND betteam = 'a' THEN 1 ELSE 0 end) as ou_away
			,SUM(CASE when bettype = 8 AND betteam = 'h' THEN 1 ELSE 0 end) as ou_1st_home
			,SUM(CASE when bettype = 8 AND betteam = 'a' THEN 1 ELSE 0 end) as ou_1st_away
		FROM bodb02.dbo.bettransm WITH(NOLOCK)
		WHERE refno IN (SELECT refno FROM @Bettrans)
			AND liveindicator = 0
			AND bettype IN (1,3,7,8)
		GROUP BY matchid
	)

	SELECT m.leagueid
		,m.matchid
		,m.homeid
		,m.awayid
		,hdp_home
		,hdp_away
		,hdp_1st_home
		,hdp_1st_away
		,ou_home
		,ou_away
		,ou_1st_home
		,ou_1st_away
	FROM T 
		INNER JOIN bodb02.dbo.match m WITH(NOLOCK) ON T.matchid = m.matchid
	WHERE m.eventstatus = 'running' 
END



GO
GRANT EXECUTE ON [dbo].[RMS_Rpt_Parlay_DangerMonitor] TO [bodbRMSNet]