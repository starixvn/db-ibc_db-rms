ALTER PROCEDURE [dbo].[RMS_Similar_Parlay_Betlist]
	@transid	BIGINT
AS
	/*
		Created: Johnson
		Date: 2012-11-09
		Task: Get similar bets parlay tickets
		DB: DBRMS/bobd_RMS
		
		Revisions:
			- 20130205@Johnson: move bettransParlay from bodb02 to bodb_RMS and rename to rmBettrans
			- 20150404@Elodie: change Net Win after PT instead of Max Pay Out after PT
			- 20160927@Winnie: fix issue conflict refno with racing 
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
	SELECT @refno = refno, @combo = right(betcheck,len(betcheck)-1) FROM rmBettrans WITH(NOLOCK) WHERE transid = @transid
	
	/*for testing on local*/
	--IF @@Servername = 'DB215' 
	--	SELECT @yesterday = '2012-11-05'

	INSERT INTO @Selection (matchid, bettype, betteam)
	SELECT a.matchid, bettype, betteam
	FROM bodb02.dbo.bettransm a WITH(NOLOCK)
	INNER JOIN bodb02.dbo.match m(NOLOCK) ON a.matchid=m.matchid	
	WHERE refno = @refno AND m.sporttype<=99
	UNION
	SELECT a.matchid, bettype, betteam
	FROM bodb02.dbo.bettransm14 a WITH(NOLOCK)
	INNER JOIN bodb02.dbo.match14 m(NOLOCK) ON a.matchid=m.matchid	
	WHERE refno = @refno AND m.sporttype<=99	
	
	INSERT INTO @bettrans(transid ,refno)
	SELECT mt.transid, mt.refno 
	FROM rmTransaction mt WITH(NOLOCK) 
		INNER JOIN rmBettrans b WITH(NOLOCK) ON mt.transid = b.transid
	WHERE mt.combo = @combo 		
		AND statusid = 0
		AND winlostdate > @yesterday
	
	INSERT INTO @result(refno,cnt)
	SELECT refno,count(1)
	FROM 
	(
		SELECT b.refno, bm.matchid, bettype, betteam
		FROM bodb02.dbo.bettransm bm WITH(NOLOCK)
			INNER JOIN @bettrans b ON bm.refno = b.refno	
			INNER JOIN bodb02.dbo.match m(NOLOCK) ON bm.matchid=m.matchid	
			WHERE m.sporttype<=99		 
		UNION 
		SELECT b.refno, bm.matchid, bettype, betteam
		FROM bodb02.dbo.bettransm14 bm WITH(NOLOCK)
			INNER JOIN @bettrans b ON bm.refno = b.refno
			INNER JOIN bodb02.dbo.match14 m(NOLOCK) ON bm.matchid=m.matchid	
			WHERE m.sporttype<=99	
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
		,odds
		,stake*actualrate*(1-p.tpositiontaking) as stake
		,stake*(odds-1)*actualrate*(1-p.tpositiontaking) as net_win
		,@combo as combo
		,@cnt_bets as cnt_bets
	FROM rmBettrans p WITH(NOLOCK) 
		LEFT JOIN rmCustomer c WITH(NOLOCK) ON p.custid = c.custid
	WHERE transid = @transid
	
	SELECT p.transid
		,p.refno
		,p.username
		,isnull(c.level,0) as level
		,stake*(odds-1)*actualrate*(1-p.tpositiontaking) as net_win
		,cnt as similar_combo 
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
GRANT EXECUTE ON [dbo].[RMS_Similar_Parlay_Betlist] TO [bodbRMSNet]
