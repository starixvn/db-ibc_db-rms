 ALTER PROCEDURE [dbo].[RMS_Rpt_Parlay_Outstanding_Ag]
	@username NVARCHAR(50),
	@winlostdate DATETIME,
	@combo		INT = 0,
	@sporttype	INT = 0
AS
	/*
		Created: Johnson
		Date: 2013-05-14
		Task: Get parlay betlist running by agent
		DB: DBRMS/bodb_RMS
		
		Revisions:
		
		Parameter's Explanation:
			-@sporttype = 0 : all sports
						= 1 : soccer only
						= 2 : Other sports
						= 3 : combined sports
	*/
SET NOCOUNT ON
	DECLARE @agentid INT
	
	SELECT @agentid = custid FROM bodb02.dbo.customer WITH(NOLOCK) WHERE username = @username
	
	IF @agentid IS NULL
		RETURN
	SELECT @combo = NULLIF(@combo,0),
			@sporttype = NULLIF(@sporttype,0)
					
	SELECT username,
		SUM(stake*actualrate*(1-tpositiontaking)) as stakePT,
		SUM(stake*actualrate*odds*(1-tpositiontaking)) as maxpayout,
		COUNT(1) as betcount
	FROM rmBettrans WITH(NOLOCK)
	WHERE recommend = @agentid
		AND matchid = 9
		AND statusid = 0
		AND winlostdate = @winlostdate
		AND liveawayscore = ISNULL(@sporttype,liveawayscore)
		AND right(betcheck,len(betcheck)-1) = ISNULL(@combo,right(betcheck,len(betcheck)-1))
	GROUP BY username

GO
GRANT EXECUTE ON [dbo].[RMS_Rpt_Parlay_Outstanding_Ag] TO [bodbRMSNet]