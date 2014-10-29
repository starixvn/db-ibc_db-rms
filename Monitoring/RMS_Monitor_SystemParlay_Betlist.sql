 ALTER PROCEDURE [dbo].[RMS_Monitor_SystemParlay_Betlist]
	@selection		VARCHAR(100) = '',
	@sporttype		VARCHAR(100) = '',
	@level			VARCHAR(100) = '',
	@Market			VARCHAR(100) = '',
	@stake			MONEY= 0,
	@maxpayout		MONEY= 0,
	@ReportType		TINYINT = 1,
	@max_transid	BIGINT = 0,
	@limitRowCount	INT = 20
AS
	/*
		Created: Johnson
		Date: 2014-01-21
		Tak: Get system parlay bets for monitoring
		DB: DBRMS/bodb_RMS
		
		Revisions:
			- 20140425@Johnson: add column IP
			- 20140620@Johnson: add option filter by net win after pt
			- 20141028@Johnson: filter tickets by specific market
		Parameter's Explanation:	
			- @combo:- '3,4': 3,4 selections						 
			- @sporttype:= '1' : soccer only
						= '2' : Other sports
						= '3' : combined sports
			- @level:= '0': none
					 = '1,2,3': level 1,2,3
			- @ReportType = 1: filter by stake
						= 2: filter by net win after pt
			- @Market = 1: Today only maket
						2: Early only maket
						3: Combined
						
	*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @tmpSelection TABLE (selection int)
	DECLARE @tmpSport TABLE (sporttype int)
	DECLARE @tmpLevel TABLE (level int)
	DECLARE @tmpMarket TABLE (type INT)
	CREATE TABLE #bettransm(refno BIGINT, transid BIGINT, today BIT DEFAULT(0), early BIT DEFAULT(0), type INT)
	DECLARE @today DATETIME
	
	SELECT @today = CONVERT(VARCHAR(10),GETDATE(),120)
	
	INSERT INTO @tmpSelection
	SELECT val
	FROM f_RMS_strSplit (@selection,',')
	
	INSERT INTO @tmpSport (sporttype)
	SELECT val
	FROM f_RMS_strSplit (@sporttype,',')
	
	INSERT INTO @tmpLevel (level)
	SELECT val
	FROM f_RMS_strSplit (@level,',')
	
	INSERT INTO @tmpMarket
	SELECT val
	FROM f_RMS_strSplit (@Market,',')
	
	INSERT INTO #bettransm(refno,transid)
	SELECT refno, transid
	FROM rmBettrans b WITH(NOLOCK) 				
	WHERE b.combo IN (SELECT selection FROM @tmpSelection)
		AND b.transid > @max_transid 						
		AND b.matchid = 29
		AND b.statusid = 0
		AND currency <> 20
	
	UPDATE b
	SET today = 1
	FROM #bettransm b
		INNER JOIN bodb02.dbo.bettransm bm WITH(NOLOCK) ON b.refno = bm.refno
	WHERE matchdate = @today	
	
	UPDATE b
	SET early = 1
	FROM #bettransm b
		INNER JOIN bodb02.dbo.bettransm bm WITH(NOLOCK) ON b.refno = bm.refno
	WHERE matchdate <> @today
	
	UPDATE b
	SET early = 1
	FROM #bettransm b
		INNER JOIN bodb02.dbo.bettransm14 bm WITH(NOLOCK) ON b.refno = bm.refno
	WHERE matchdate <> @today
		AND early = 0	
	
	UPDATE #bettransm
	SET type = CASE WHEN today = 1 AND early = 0 THEN 1
					WHEN today = 0 AND early = 1 THEN 2
					ELSE 3 END
	
			
	IF EXISTS(SELECT 1 FROM @tmpLevel WHERE level = 0)
	BEGIN
			
		SELECT top (@limitRowcount)
			transdate,
			transid,
			refno,
			username,	
			IP,		
			stake,	
			odds,
			r.maxpayout,				
			combo,
			level
		FROM
		(
			SELECT
				b.transdate,
				b.transid,
				b.refno, 
				b.username,
				b.liveawayscore as sporttype,			
				b.statusid,
				b.IP,
				(case when b.combo = 3 then b.stake/4
					WHEN b.combo = 4 then b.stake/11
					WHEN b.combo = 5 THEN b.stake/26
					WHEN b.combo = 6 THEN b.stake/57
					WHEN b.combo = 7 THEN b.stake/120
					when b.combo = 8 THEN b.stake/247 END)*b.actualrate*(1-b.tpositiontaking) as stake,	
				b.odds2 as odds,
				(case when b.combo = 3 then b.stake/4
					WHEN b.combo = 4 then b.stake/11
					WHEN b.combo = 5 THEN b.stake/26
					WHEN b.combo = 6 THEN b.stake/57
					WHEN b.combo = 7 THEN b.stake/120
					when b.combo = 8 THEN b.stake/247 END)*b.actualrate*(1-b.tpositiontaking)*(odds2-case when b.combo = 3 then 4
																										WHEN b.combo = 4 then 11
																										WHEN b.combo = 5 THEN 26
																										WHEN b.combo = 6 THEN 57
																										WHEN b.combo = 7 THEN 120
																										when b.combo = 8 THEN 247 end) as maxpayout,												
				b.combo,				
				ISNULL(mc.level,0) level
			FROM rmBettrans b WITH(NOLOCK) 
				LEFT JOIN rmCustomer mc WITH(NOLOCK) ON b.custid = mc.custid
			WHERE  b.transid IN (SELECT transid 
								FROM #bettransm
								WHERE type IN (SELECT type FROM @tmpMarket)
							)	
		)r
		WHERE level IN (SELECT [level] FROM @tmpLevel)
			AND 1 = case when @ReportType = 1 AND stake >= @stake THEN 1 
						when @ReportType = 2 AND r.maxpayout >= @maxpayout then 1 else 0 end 
			AND sporttype IN (SELECT sporttype FROM @tmpSport)	
		ORDER BY transid DESC
	END
	ELSE
	BEGIN			
		SELECT top (@limitRowCount)
			transdate,
			transid,
			refno,
			username,	
			IP,		
			stake,	
			r.odds,
			r.maxpayout,					
			combo,
			level
		FROM 
		(
			SELECT
 				b.transdate,
				b.transid,
				b.refno, 
				b.username,
				b.liveawayscore as sporttype,			
				b.statusid,
				b.IP,
				(case when b.combo = 3 then b.stake/4
					WHEN b.combo = 4 then b.stake/11
					WHEN b.combo = 5 THEN b.stake/26
					WHEN b.combo = 6 THEN b.stake/57
					WHEN b.combo = 7 THEN b.stake/120
					when b.combo = 8 THEN b.stake/247 END)*b.actualrate*(1-b.tpositiontaking) as stake,				
				b.odds2 as odds,
				(case when b.combo = 3 then b.stake/4
					WHEN b.combo = 4 then b.stake/11
					WHEN b.combo = 5 THEN b.stake/26
					WHEN b.combo = 6 THEN b.stake/57
					WHEN b.combo = 7 THEN b.stake/120
					when b.combo = 8 THEN b.stake/247 END)*b.actualrate*(1-b.tpositiontaking)*(odds2-case when b.combo = 3 then 4
																										WHEN b.combo = 4 then 11
																										WHEN b.combo = 5 THEN 26
																										WHEN b.combo = 6 THEN 57
																										WHEN b.combo = 7 THEN 120
																										when b.combo = 8 THEN 247 end) as maxpayout,								
				b.combo,				
				ISNULL(mc.level,0) level
			FROM rmCustomer mc WITH(NOLOCK) 			
				INNER JOIN rmBettrans b WITH(NOLOCK) ON b.custid = mc.custid
			WHERE [level] IN (SELECT [level] FROM @tmpLevel)
				 AND b.transid IN (SELECT transid 
								FROM #bettransm
								WHERE type IN (SELECT type FROM @tmpMarket)
							)						
		) r
		WHERE 1 = case when @ReportType = 1 AND stake >= @stake THEN 1 
						when @ReportType = 2 AND r.maxpayout >= @maxpayout then 1 else 0 end 			
			AND sporttype IN (SELECT sporttype FROM @tmpSport)	
		ORDER BY transid DESC
	END
	
		
END

GO
GRANT EXECUTE ON [dbo].[RMS_Monitor_SystemParlay_Betlist] TO [bodbRMSNet]
