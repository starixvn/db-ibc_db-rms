ALTER PROCEDURE [dbo].[RMS_Monitor_Parlay_Betlist]
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
		Date: 2012-10-25
		Task: Monitoring bets parlay of special members
		DB: DBRMS/bodb_RMS
		
		Revisions:
			- 20130125@Johnson: move bettransParlay from bodb02 to bodb_RMS and rename to rmBettrans
			- 20130923@Johnson: exclude test currency
			- 20140417@Johnson: filter by stake instead of max pay out
			- 20140418@Johnson: add column IP
			- 20140620@Johnson: add more option filter by net win after pt
			- 20141028@Johnson: filter tickets by specific market
			- 20150323@Elodie: Add signs to indicate the presence of the BetRadar bet types on Parlay tickets [Red:#30517]

		Parameter's Explanation:
			- @selection:- '2,3': 2,3 selections
						 - '6': 6 UP
			- @sporttype:= '1' : soccer only
						= '2' : Other sports
						= '3' : combined sports
			- @level:= '0': none
					 = '1,2,3': level 1,2,3
			- @ReportType = 1: Filter by stake
						= 2: filter by net win
			- @Market = 1: Today only maket
						2: Early only maket
						3: Combined
	*/
SET NOCOUNT ON 
	----Get Sport Bettype Matrix------
	DECLARE @BetRadar TABLE(ProductID INT, Bettype INT,EventType INT)
	INSERT INTO @BetRadar
	EXEC bodb02.dbo.Acc_SportBettypeMatrix_Sel @Mode = 4, @SubProduct = 'BetRadar'

	DECLARE @tmpSelection TABLE (selection int)
	DECLARE @tmpSport TABLE (sporttype int)
	DECLARE @tmpMarket TABLE(type INT)
	CREATE TABLE #bettransm(refno BIGINT, transid BIGINT, today BIT DEFAULT(0), early BIT DEFAULT(0), type INT, IsBetRadar BIT DEFAULT(0))
	DECLARE @tmpLevel TABLE (level int)
	DECLARE @6up varchar(100), @today DATETIME
	
	SELECT @today = CONVERT(VARCHAR(10),GETDATE(),120)
			
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
	
	INSERT INTO @tmpMarket
	SELECT val
	FROM f_RMS_strSplit (@Market,',')
	
	INSERT INTO #bettransm(refno,transid)
	SELECT refno, transid
	FROM rmBettrans b WITH(NOLOCK) 				
	WHERE b.combo IN (SELECT selection FROM @tmpSelection)
		AND b.transid > @max_transid 						
		AND b.matchid = 9
		AND b.statusid = 0
		AND currency <> 20
	
	UPDATE #bettransm
	SET IsBetRadar = 1
	FROM #bettransm b
		INNER JOIN bodb02.dbo.bettransm bm WITH(NOLOCK) ON b.refno = bm.refno
	WHERE bm.bettype IN (SELECT Bettype FROM @BetRadar)

	UPDATE #bettransm
	SET IsBetRadar = 1
	FROM #bettransm b
		INNER JOIN bodb02.dbo.bettransm14 bm WITH(NOLOCK) ON b.refno = bm.refno
	WHERE bm.bettype IN (SELECT Bettype FROM @BetRadar)

	UPDATE #bettransm
	SET today = 1
	FROM #bettransm b
		INNER JOIN bodb02.dbo.bettransm bm WITH(NOLOCK) ON b.refno = bm.refno
	WHERE matchdate = @today	
	
	UPDATE #bettransm
	SET early = 1
	FROM #bettransm b
		INNER JOIN bodb02.dbo.bettransm bm WITH(NOLOCK) ON b.refno = bm.refno
	WHERE matchdate <> @today
	
	UPDATE #bettransm
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
			odds,
			stake,
			maxpayout,			
			combo,
			IP,
			level,
			IsBetRadar
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
				ISNULL(mc.level,0) level,
				bm.IsBetRadar
			FROM rmBettrans b WITH(NOLOCK) 
				INNER JOIN #bettransm bm ON b.transid = bm.transid
				LEFT JOIN rmCustomer mc WITH(NOLOCK) ON b.custid = mc.custid
			WHERE bm.type IN (SELECT type FROM @tmpMarket)
		)r
		WHERE level IN (SELECT [level] FROM @tmpLevel)
			AND 1= case when @reportType = 1 AND r.stake >= @stake then 1
						when @reportType = 2 AND r.maxpayout >= @maxpayout then 1 else 0 end
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
			level,
			IsBetRadar
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
				ISNULL(mc.level,0) level,
				bm.IsBetRadar
			FROM rmCustomer mc WITH(NOLOCK) 			
				INNER JOIN rmBettrans b WITH(NOLOCK) ON b.custid = mc.custid
				INNER JOIN #bettransm bm ON b.transid = bm.transid
			WHERE [level] IN (SELECT [level] FROM @tmpLevel)
				AND bm.type IN (SELECT type FROM @tmpMarket)			
		) r
		WHERE 1= case when @ReportType = 1 AND r.stake >= @stake then 1 
						when @ReportType = 2 AND r.maxpayout >= @maxpayout then 1 else 0 END 
			AND sporttype IN (SELECT sporttype FROM @tmpSport)	
		ORDER BY transid DESC
	END		
	


