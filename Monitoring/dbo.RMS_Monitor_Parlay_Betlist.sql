 ALTER PROCEDURE [dbo].[RMS_Monitor_Parlay_Betlist]
	@selection		VARCHAR(100) = '',
	@sporttype		VARCHAR(100) = '',
	@level			VARCHAR(100) = '',
	@stake			MONEY= 0,
	@max_transid	BIGINT = 0,
	@limitRowCount	INT = 20
 AS
	/*
		Created: Johnson
		Date: 2012-10-25
		Task: Monitoring bets parlay of special members
		DB: DBRMS/bodb_RMS
		
		Revisions:
			- 20130125@Johnson: move bettransParlay from bodb02 to bodb_RMS and rename to rmBettrans
			- 20130923@Johnson: exclude test currency
			- 20140417@Johnson: filter by stake instead of max pay out
			- 20140418@Johnson: add column IP
		Parameter's Explanation:
			- @selection:- '2,3': 2,3 selections
						 - '6': 6 UP
			- @sporttype:= '1' : soccer only
						= '2' : Other sports
						= '3' : combined sports
			- @level:= '0': none
					 = '1,2,3': level 1,2,3
	*/
SET NOCOUNT ON 
	DECLARE @tmpSelection TABLE (selection int)
	DECLARE @tmpSport TABLE (sporttype int)
	DECLARE @tmpLevel TABLE (level int)
	DECLARE @6up varchar(100)
			
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
			IP,
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
				(b.odds-1)*b.stake*actualrate*(1-b.tpositiontaking) as maxpayout,		
				b.combo,
				b.IP,				
				ISNULL(mc.level,0) level
			FROM rmBettrans b WITH(NOLOCK) 
				LEFT JOIN rmCustomer mc WITH(NOLOCK) ON b.custid = mc.custid
			WHERE b.combo IN (SELECT selection FROM @tmpSelection)
				AND b.transid > @max_transid 						
				AND b.matchid = 9
				AND b.statusid = 0
				AND currency <> 20	
		)r
		WHERE level IN (SELECT [level] FROM @tmpLevel)
			AND r.stake >= @stake
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
			IP,
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
				(b.odds-1)*b.stake*actualrate*(1-b.tpositiontaking) as maxpayout,		
				b.combo,			
				b.IP,	
				ISNULL(mc.level,0) level
			FROM rmCustomer mc WITH(NOLOCK) 			
				INNER JOIN rmBettrans b WITH(NOLOCK) ON b.custid = mc.custid
			WHERE [level] IN (SELECT [level] FROM @tmpLevel)
				AND b.combo IN (SELECT selection FROM @tmpSelection)
				AND b.transid > @max_transid 		
				--AND b.bettype = 9
				AND b.matchid = 9
				AND b.statusid = 0			
				AND currency <> 20						
		) r
		WHERE r.stake >= @stake
			AND sporttype IN (SELECT sporttype FROM @tmpSport)	
		ORDER BY transid DESC
	END		
	


GO
GRANT EXECUTE ON [dbo].[RMS_Monitor_Parlay_Betlist] TO [bodbRMSNet]