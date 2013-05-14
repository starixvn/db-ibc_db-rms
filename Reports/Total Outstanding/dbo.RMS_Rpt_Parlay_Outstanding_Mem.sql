ALTER PROCEDURE [dbo].[RMS_Rpt_Parlay_Outstanding_Mem]
	@username	NVARCHAR(50),
	@winlostdate DATETIME,
	@combo		INT = 0,
	@sporttype	INT = 0
AS
	/*
		Created: Johnson
		Date: 2013-05-14
		Task: Get parlay betlist running by member
		DB: DBRMS/bodb_RMS
		
		Revisions:
		
		Parameter's Explanation:	
			-@sporttype = 0 : all sports
						= 1 : soccer only
						= 2 : Other sports
						= 3 : combined sports
	*/ 
SET NOCOUNT ON
	DECLARE @custid INT
	
	SELECT @custid = custid FROM bodb02.dbo.customer WITH(NOLOCK) WHERE username = @username
	
	IF @custid IS NULL
		RETURN
	
	SELECT @combo = NULLIF(@combo,0),
			@sporttype = NULLIF(@sporttype,0)
			
	SELECT transid,
		transdate,
		odds,
		stake*actualrate stake,
		stake*actualrate*(1-tpositiontaking) stakePT,
		stake*actualrate*odds*(1-tpositiontaking) maxpayoutPT,
		right(betcheck,len(betcheck)-1) combo
	FROM rmBettrans WITH(NOLOCK)
	WHERE custid = @custid 
		AND matchid = 9
		AND statusid = 0
		AND winlostdate = @winlostdate
		AND liveawayscore = ISNULL(@sporttype,liveawayscore)
		AND right(betcheck,len(betcheck)-1) = ISNULL(@combo,right(betcheck,len(betcheck)-1))
	

GO
GRANT EXECUTE ON [dbo].[RMS_Rpt_Parlay_Outstanding_Mem] TO [bodbRMSNet]