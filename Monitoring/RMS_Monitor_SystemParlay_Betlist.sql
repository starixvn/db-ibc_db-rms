 ALTER PROCEDURE [dbo].[RMS_Monitor_SystemParlay_Betlist]
	@selection		VARCHAR(100) = '',
	@sporttype		VARCHAR(100) = '',
	@level			VARCHAR(100) = '',
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
		Parameter's Explanation:	
			- @combo:- '3,4': 3,4 selections						 
			- @sporttype:= '1' : soccer only
						= '2' : Other sports
						= '3' : combined sports
			- @level:= '0': none
					 = '1,2,3': level 1,2,3
			- @ReportType = 1: filter by stake
						= 2: filter by net win after pt
	*/
BEGIN
	SET NOCOUNT ON
	CREATE TABLE #result 
			(	
				transdate datetime,
				transid bigint primary key,				
				refno bigint,
				username varchar(50),
				IP varchar(50),
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
			WHERE b.combo IN (SELECT selection FROM @tmpSelection)
				AND b.transid > @max_transid 						
				AND b.matchid = 29
				AND b.statusid = 0
				AND currency <> 20	
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
				AND b.combo IN (SELECT selection FROM @tmpSelection)
				AND b.transid > @max_transid 						
				AND b.matchid = 29
				AND b.statusid = 0			
				AND currency <> 20						
		) r
		WHERE 1 = case when @ReportType = 1 AND stake >= @stake THEN 1 
						when @ReportType = 2 AND r.maxpayout >= @maxpayout then 1 else 0 end 			
			AND sporttype IN (SELECT sporttype FROM @tmpSport)	
		ORDER BY transid DESC
	END
	
		
END

GO
GRANT EXECUTE ON [dbo].[RMS_Monitor_SystemParlay_Betlist] TO [bodbRMSNet]
