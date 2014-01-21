 CREATE PROCEDURE [dbo].[RMS_Monitor_SystemParlay_Betlist]
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
			odds,
			stake,
			maxpayout,			
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
				b.odds,
				b.statusid,
				b.stake*b.actualrate*(1-b.tpositiontaking) as stake,
				b.odds*b.stake*actualrate*(1-b.tpositiontaking) as maxpayout,		
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
		SELECT top (@limitRowCount)
			transdate,
			transid,
			refno,
			username,
			odds,
			stake,
			maxpayout,			
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
				b.odds,
				b.statusid,
				b.stake*b.actualrate*(1-b.tpositiontaking) as stake,
				b.odds*b.stake*actualrate*(1-b.tpositiontaking) as maxpayout,		
				mt.combo,				
				ISNULL(mc.level,0) level
			FROM rmCustomer mc WITH(NOLOCK) 			
				INNER JOIN rmTransaction mt WITH(NOLOCK) ON mt.custid = mc.custid
				INNER JOIN rmBettrans b WITH(NOLOCK) ON mt.transid = b.transid
			WHERE [level] IN (SELECT [level] FROM @tmpLevel)
				AND mt.combo IN (SELECT selection FROM @tmpSelection)
				AND mt.transid > @max_transid 		
				--AND b.bettype = 9
				AND b.matchid = 29
				AND b.statusid = 0			
				AND currency <> 20						
		) r
		WHERE stake >= @stake
			AND sporttype IN (SELECT sporttype FROM @tmpSport)	
		ORDER BY transid DESC
	END		
END

GO
GRANT EXECUTE ON [dbo].[RMS_Monitor_SystemParlay_Betlist] TO [bodbRMSNet]
