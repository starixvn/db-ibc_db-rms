 ALTER PROCEDURE [dbo].[RMS_Rpt_Parlay_TopWinners_Details_Old]
	@custid			INT,
	@fromdate		DATETIME,
	@todate			DATETIME,
	@sporttype		TINYINT = NULL,
	@selection		VARCHAR(100) = ''
 AS
	/*
		Created: Johnson
		Date: 20121204
		Task: get parlay betlist for top winners before balanceup date
		DB:DBARC/bodb_Archive
		
		Revisions:
			- 20130121@Johnson: Move sp from DB06.BODB02 to DBARC.bodb_Archive
			- 20130225@Johnson: include lose tickets into report
			- 20130813@Johnson: add combination filter
		Parameter's Explanation:
	*/
SET NOCOUNT ON
	DECLARE @tmpBettrans TABLE (transid BIGINT PRIMARY KEY
				,refno BIGINT
				,sporttype TINYINT
				,stake MONEY
				,winlost MONEY
				,company_winlost MONEY
				,stake_baseRM MONEY
				,winlost_baseRM MONEY
				,company_winlost_baseRM MONEY
				,combo TINYINT
				,odds SMALLMONEY
			)
	DECLARE @tmpSelection TABLE(selection tinyint)	
	DECLARE @6UP VARCHAR(200)
	
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
	
	INSERT INTO @tmpBettrans (transid
				,refno
				,sporttype
				,stake
				,winlost
				,company_winlost
				,stake_baseRM
				,winlost_baseRM
				,company_winlost_baseRM
				,combo
				,odds)		
	SELECT transid
		,refno
		,liveawayscore
		,stake
		,winlost-actual_stake
		,-(winlost-actual_stake)*(1-tpositiontaking)
		,stake*actualrate
		,(winlost-actual_stake)*actualrate
		,-(winlost-actual_stake)*(1-tpositiontaking)*actualrate
		,RIGHT(betcheck,len(betcheck)-1)
		,modds
	FROM dbo.bettrans_bk WITH(NOLOCK, INDEX = IX_CustID)
	WHERE custid = @custid
		AND matchid = 9 		
		AND winlostdate BETWEEN @fromdate AND @todate
		AND statusid IN (112,113)

	SELECT * FROM @tmpBettrans
	WHERE sporttype = ISNULL(@sporttype,sporttype)
		AND combo IN (SELECT selection FROM @tmpSelection)
	ORDER BY transid DESC
	
GO
GRANT EXECUTE ON [dbo].[RMS_Rpt_Parlay_TopWinners_Details_Old] TO [bodbRMSNet]