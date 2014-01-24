 ALTER PROCEDURE [dbo].[RMS_Monitor_SystemParlay_Betlist]
	@selection		VARCHAR(100) = '',
	@sporttype		VARCHAR(100) = '',
	@level			VARCHAR(100) = '',
	@stake			MONEY= 0,
	@max_transid	BIGINT = 0,
	@limitRowCount	INT = 20
AS
	/*
		Created: Johnson
		Date: 2014-01-21
		Tak: Get system parlay bets for monitoring
		DB: DBRMS/bodb_RMS
		
		Revisions:
		
		Parameter's Explanation:	
			- @combo:- '3,4': 3,4 selections						 
			- @sporttype:= '1' : soccer only
						= '2' : Other sports
						= '3' : combined sports
			- @level:= '0': none
					 = '1,2,3': level 1,2,3
	*/
BEGIN
	SET NOCOUNT ON
	CREATE TABLE #result 
			(	
				transdate datetime,
				transid bigint primary key,				
				refno bigint,
				username varchar(50),
				stake money,
				combo int,
				level int	
			)
	
	DECLARE @tmpSelection TABLE (selection int)
	DECLARE @tmpSport TABLE (sporttype int)
	DECLARE @tmpLevel TABLE (level int)
	
	INSERT INTO @tmpSelection
	SELECT val
	FROM f_RMS_strSplit (@selection,',')
	
	INSERT INTO @tmpSport (sporttype)
	SELECT val
	FROM f_RMS_strSplit (@sporttype,',')
	
	INSERT INTO @tmpLevel (level)
	SELECT val
	FROM f_RMS_strSplit (@level,',')
			
	IF EXISTS(SELECT 1 FROM @tmpLevel WHERE level = 0)
	BEGIN
		INSERT INTO #result(
			transdate,			
			transid,
			refno,
			username,			
			stake,			
			combo,
			level)		
		SELECT top (@limitRowcount)
			transdate,
			transid,
			refno,
			username,			
			stake,					
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
				(case when mt.combo = 3 then b.stake/4
					WHEN mt.combo = 4 then b.stake/11
					WHEN mt.combo = 5 THEN b.stake/26
					WHEN mt.combo = 6 THEN b.stake/57
					WHEN mt.combo = 7 THEN b.stake/120
					when mt.combo = 8 THEN b.stake/247 END)*b.actualrate*(1-b.tpositiontaking) as stake,				
				mt.combo,				
				ISNULL(mc.level,0) level
			FROM rmTransaction mt WITH(NOLOCK)				
				INNER JOIN rmBettrans b WITH(NOLOCK) ON mt.transid = b.transid
				LEFT JOIN rmCustomer mc WITH(NOLOCK) ON mt.custid = mc.custid
			WHERE mt.combo IN (SELECT selection FROM @tmpSelection)
				AND mt.transid > @max_transid 						
				AND b.matchid = 29
				AND b.statusid = 0
				AND currency <> 20	
		)r
		WHERE level IN (SELECT [level] FROM @tmpLevel)
			AND stake >= @stake
			AND sporttype IN (SELECT sporttype FROM @tmpSport)	
		ORDER BY transid DESC
	END
	ELSE
	BEGIN
		INSERT INTO #result(transdate,
			transid,
			refno,
			username,			
			stake,		
			combo,
			level)	
		SELECT top (@limitRowCount)
			transdate,
			transid,
			refno,
			username,			
			stake,						
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
				(case when mt.combo = 3 then b.stake/4
					WHEN mt.combo = 4 then b.stake/11
					WHEN mt.combo = 5 THEN b.stake/26
					WHEN mt.combo = 6 THEN b.stake/57
					WHEN mt.combo = 7 THEN b.stake/120
					when mt.combo = 8 THEN b.stake/247 END)*b.actualrate*(1-b.tpositiontaking) as stake,				
				mt.combo,				
				ISNULL(mc.level,0) level
			FROM rmCustomer mc WITH(NOLOCK) 			
				INNER JOIN rmTransaction mt WITH(NOLOCK) ON mt.custid = mc.custid
				INNER JOIN rmBettrans b WITH(NOLOCK) ON mt.transid = b.transid
			WHERE [level] IN (SELECT [level] FROM @tmpLevel)
				AND mt.combo IN (SELECT selection FROM @tmpSelection)
				AND mt.transid > @max_transid 						
				AND b.matchid = 29
				AND b.statusid = 0			
				AND currency <> 20						
		) r
		WHERE stake >= @stake
			AND sporttype IN (SELECT sporttype FROM @tmpSport)	
		ORDER BY transid DESC
	END
	
	select * from #result
	
	SELECT refno , odds
	FROM(
			SELECT refno, odds
			from bodb02.dbo.bettransm with(NOLOCK)
			where refno in (SELECT refno from #result)
			UNION ALL 
			SELECT refno, odds
			from bodb02.dbo.bettransm14 with(NOLOCK)
			where refno in (SELECT refno from #result)
	)r	
	order by refno
		
END

GO
GRANT EXECUTE ON [dbo].[RMS_Monitor_SystemParlay_Betlist] TO [bodbRMSNet]
