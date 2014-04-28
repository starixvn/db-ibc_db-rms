ALTER PROCEDURE [dbo].[RMS_SystemParlay_CombinationDetails] 
	@refno	BIGINT = 0,
	@Outstanding MONEY = 0 OUTPUT
AS
	/*
		Created: Johnson
		Date: 2014-04-18
		Task: Get details info for Combination System Parlay
		DB: DBRMS/bodb_RMS
		
	*/ 
BEGIN
	SET NOCOUNT ON
	
	DECLARE @tmpResults TABLE (
		winlostdate DATETIME,
		transid		BIGINT,
		serial		BIGINT,
		statusid	INT,
		status		VARCHAR(20),	
		modds		SMALLMONEY,
		stake		MONEY,
		winlost		MONEY
	)

	DECLARE @betParlayDetail TABLE (
		RefNo		bigint, 
		Serial		int, 				 				
		matchid		int				
	)
	
	DECLARE @tmpMatch AS TABLE(
			serial		BIGINT,
			homeid		INT,
			awayid		INT
		)	
		
	INSERT INTO @tmpResults(winlostdate, serial, modds, stake, winlost, statusid)
		SELECT winlostdate, serial, modds, stake, winlost, statusid
		FROM bodb02.dbo.betparlayresult b WITH(NOLOCK) 
		WHERE refno = @refno
	
	INSERT INTO @betParlayDetail(RefNo, Serial, matchid )
		SELECT refno, serial, matchid
		FROM bodb02.dbo.betParlayDetail WITH(NOLOCK)
		WHERE refno = @refno
	
	INSERT INTO @tmpMatch
		SELECT
			p.serial,
			homeid,
			awayid
		FROM @tmpResults p 
			INNER JOIN @betParlayDetail b ON p.Serial = b.Serial
			INNER JOIN bodb02.dbo.match m WITH(NOLOCK) ON b.matchid = m.matchid	
		WHERE p.statusid <> 113
		union 
		SELECT
			p.serial,
			homeid,
			awayid
		FROM @tmpResults p 
			INNER JOIN @betParlayDetail b ON p.Serial = b.Serial
			INNER JOIN bodb02.dbo.match14 m WITH(NOLOCK) ON b.matchid = m.matchid	
		WHERE p.statusid <> 113
	
	SELECT @outStanding = stake
	FROM rmBettrans WITH(NOLOCK) 
	WHERE matchid = 29  
		AND refno = @refno
	
	SELECT @outStanding = @outStanding - ISNULL(SUM(stake),0)
	FROM @tmpResults
	WHERE statusid not in (0,1)
		
	-- return combo detail
	SELECT 
		winlostdate,
		0 transid,
		serial,
		statusid,	
		CASE statusid WHEN 101 THEN 'REJECT'
						WHEN 102 THEN 'VOID'
						WHEN 103 THEN 'REFUND'
						WHEN 111 THEN 'DRAW'
						WHEN 112 THEN 'WON' ELSE '' END AS status,
		modds,
		stake,
		winlost - stake AS winlost
	FROM @tmpResults
	WHERE statusid NOT IN (0,1,113)

	UNION ALL

	SELECT 
		winlostdate,	
		0 AS transid,	
		0 AS serial,
		113 AS statusid,	
		'LOSE' AS status,
		0 AS modds,	
		SUM(stake) AS stake,	
		SUM(winlost - stake) AS winlost
	FROM @tmpResults
	WHERE statusid = 113
	GROUP BY 
		winlostdate 
	ORDER BY winlostdate ASC

	SELECT * FROM @tmpMatch
	
END
GO
GRANT EXECUTE ON [dbo].[RMS_SystemParlay_CombinationDetails] TO [bodbRMSNet]