 ALTER PROCEDURE [dbo].[RMS_Rpt_Parlay_TopWinners_Details_Old]
	@custid			INT,
	@fromdate		DATETIME,
	@todate			DATETIME,
	@sporttype		TINYINT = NULL
 AS
	/*
		Created: Johnson
		Date: 20121204
		Task: get parlay betlist for top winners before balanceup date
		DB:DBARC/bodb_Archive
		
		Revisions:
			- 20130121@Johnson: Move sp from DB06.BODB02 to DBARC.bodb_Archive
			- 20130225@Johnson: include lose tickets into report
		Parameter's Explanation:
	*/
SET NOCOUNT ON
	DECLARE @tmpBettrans TABLE (transid BIGINT PRIMARY KEY
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
	
	INSERT INTO @tmpBettrans (transid
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
	ORDER BY transid DESC
	
GO
GRANT EXECUTE ON [dbo].[RMS_Rpt_Parlay_TopWinners_Details_Old] TO [bodbRMSNet]