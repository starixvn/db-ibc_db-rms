ALTER PROCEDURE [dbo].[RMS_Similar_ComboParlay_Betlist]
	@transid	BIGINT
AS
	/*
		Created: Winnie
		Date: 2016-04-26
		Task: Get similar bets combo parlay tickets
		DB: DBRMS/bobd_RMS		
		Revisions:
		Parameter's Explanation:
	*/ 
SET NOCOUNT ON
	IF (SELECT ISNULL(statusid,1) FROM rmBettrans WITH(NOLOCK) WHERE transid = @transid) > 0 
		RETURN
	
	DECLARE @refno BIGINT, @combo INT, @cnt_bets INT, @yesterday DATETIME
	
	DECLARE  @bettrans TABLE(transid BIGINT PRIMARY KEY,refno BIGINT)
	
	DECLARE @Selection TABLE(matchid INT, bettype int, betteam nvarchar(10))
	DECLARE @result	TABLE (refno BIGINT PRIMARY KEY, cnt INT)
	
	SELECT @yesterday = convert(varchar(10),DATEADD(dd,-1,current_timestamp),120)
	SELECT @refno = refno, @combo = hdp2 FROM rmBettrans WITH(NOLOCK) WHERE transid = @transid


	INSERT INTO @Selection (matchid, bettype, betteam)
	SELECT matchid, bettype, betteam
	FROM bodb02.dbo.bettransm WITH(NOLOCK)
	WHERE refno = @refno
	UNION
	SELECT matchid, bettype, betteam
	FROM bodb02.dbo.bettransm14 WITH(NOLOCK)
	WHERE refno = @refno
	
	INSERT INTO @bettrans(transid ,refno)
	SELECT b.transid, b.refno 
	FROM  rmBettrans b WITH(NOLOCK)
	WHERE 
		b.bettype=29
	    AND b.combo = @combo 		
		AND statusid = 0
		AND winlostdate > @yesterday
	
	INSERT INTO @result(refno,cnt)
	SELECT refno,count(1)
	FROM 
	(
		SELECT b.refno, matchid, bettype, betteam
		FROM bodb02.dbo.bettransm bm WITH(NOLOCK)
			INNER JOIN @bettrans b ON bm.refno = b.refno		 
		UNION 
		SELECT b.refno, matchid, bettype, betteam
		FROM bodb02.dbo.bettransm14 bm WITH(NOLOCK)
			INNER JOIN @bettrans b ON bm.refno = b.refno
	) r
		INNER JOIN @Selection s ON r.matchid = s.matchid AND r.bettype = s.bettype
	WHERE r.betteam = s.betteam
		AND refno <> @refno
	GROUP BY refno
	HAVING count(1) >= CASE WHEN @combo =2 THEN @combo ELSE (@combo*1.0/2) END
	
	SELECT @cnt_bets = ISNULL(COUNT(1),0) FROM @result
	
	SELECT transdate
		,transid
		,refno
		,p.username
		,isnull(c.level,0) as level
		,CASE WHEN transid2 NOT IN (-1,-3,1,2,3,4,5,6,7,8,9,11,43) THEN -2 ELSE transid2 END AS Sporttype
		,odds2*TotalBet AS odds
		,stake*actualrate*(1-p.tpositiontaking)/TotalBet  as stake
		,stake*(odds2-1)*actualrate*(1-p.tpositiontaking) as net_win		
		,p.hdp2 AS TotalSelection,
		p.TotalBet AS TotalBet,
		@cnt_bets as cnt_bets
	FROM rmBettrans p WITH(NOLOCK) 
		LEFT JOIN rmCustomer c WITH(NOLOCK) ON p.custid = c.custid
	WHERE transid = @transid and bettype=29
	
	SELECT p.transid
		,p.refno
		,p.username
		,isnull(c.level,0) as level
		,stake*(odds2-1)*actualrate*(1-p.tpositiontaking) as net_win
		,cnt as similar_selection
	FROM 
		(
			SELECT transid, cnt
			FROM @result r
			INNER JOIN @bettrans b ON r.refno = b.refno 
		)b
		INNER JOIN rmBettrans p WITH(NOLOCK) ON b.transid = p.transid
		LEFT JOIN rmCustomer c WITH(NOLOCK) ON p.custid = c.custid
	ORDER BY cnt DESC


GO
GRANT EXECUTE ON [dbo].[RMS_Similar_ComboParlay_Betlist] TO [bodbRMSNet]
