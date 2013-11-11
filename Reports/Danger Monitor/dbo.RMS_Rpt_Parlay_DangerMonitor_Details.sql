 ALTER PROCEDURE [dbo].[RMS_Rpt_Parlay_DangerMonitor_Details]
	@matchid INT,
	@AgentIDList VARCHAR(4000) = '',
	@selection  VARCHAR(500),
	@max_transid BIGINT = 0	
 AS
	/*
		Created: Johnson
		Date: 2013-10-22
		Task: Get report details for specific match
		DB: DBRMS/bodb_RMS
		
		Revisions:
		
		Parameter's Explanation:
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
			AND transid <= @max_transid
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
			AND transid <= @max_transid
	END		
	
	SELECT case when bettype in (1,7) then CASE WHEN betteam = 'h' THEN hdp2 - hdp1 else hdp1 - hdp2 end else hdp1 end as hdp
		,odds		
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
		AND matchid = @matchid
		AND bettype IN (1,3,7,8)
		AND liveindicator = 0
	GROUP BY case when bettype in (1,7) then CASE WHEN betteam = 'h' THEN hdp2 - hdp1 else hdp1 - hdp2 end else hdp1 end ,odds
	ORDER BY case when bettype in (1,7) then CASE WHEN betteam = 'h' THEN hdp2 - hdp1 else hdp1 - hdp2 end else hdp1 end

END

GO
GRANT EXECUTE ON [dbo].[RMS_Rpt_Parlay_DangerMonitor_Details] TO [bodbRMSNet]