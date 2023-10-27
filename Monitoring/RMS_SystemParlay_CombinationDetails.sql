/*<info serverAlias="DBRMS-bodb_RMS" executers="bodbRMSNet" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[RMS_SystemParlay_CombinationDetails] 
	@refno	BIGINT = 0,
	@Outstanding MONEY = 0 OUTPUT
AS
	/*
		Created: Johnson
		Date: 2014-04-18
		Task: Get details info for Combination System Parlay
		DB: DBRMS/bodb_RMS
		Revision:
			- 20231020@Cherry: Parlay Boost Bonus (#192681)
		
	*/ 
BEGIN
	SET NOCOUNT ON
	
	CREATE TABLE #tmpResults (
		winlostdate DATETIME,
		transid		BIGINT,
		serial		BIGINT,
		statusid	INT,	
		modds		SMALLMONEY,
		IsBoostBonus BIT,	
		odds		MONEY,
		odds2		MONEY,
		bbp			MONEY,
		bba			MONEY,
		stake		MONEY,
		winlost		MONEY
	)

	CREATE TABLE #BetParlayDetail (
		RefNo		bigint, 
		Serial		int, 				 				
		matchid		int				
	)
	
	CREATE TABLE #tmpMatch (
			serial		BIGINT,
			homeid		INT,
			awayid		INT
		)	
		
	INSERT INTO #tmpResults(winlostdate, serial, statusid, modds, IsBoostBonus, odds, odds2, bbp, bba, stake, winlost)
		SELECT b.winlostdate, b.serial, b.statusid, b.modds, 
			CASE WHEN bm.bettype = 29 AND bm.betteam = N'1' AND bm.oddsspread = 2 THEN 1 ELSE 0 END IsBoostBonus,
            CASE WHEN bm.bettype = 29 AND bm.betteam = N'1' AND bm.oddsspread = 2 THEN
				CAST((a.odds2 + TRY_CAST(TRY_CAST(bm.ExtraInfo AS XML).value('(/p1/@bbp)[1]', 'VARCHAR(50)') AS DECIMAL(19,6))) / 
					(1 + TRY_CAST(TRY_CAST(bm.ExtraInfo AS XML).value('(/p1/@bbp)[1]', 'VARCHAR(50)') AS DECIMAL(19,6))) AS SMALLMONEY)				
				END odds, --Original Odds
			CASE WHEN a.statusID = 112 AND ISNULL(TRY_CAST(TRY_CAST(bm.ExtraInfo AS XML).value('(/p1/@bba)[1]', 'VARCHAR(50)') AS DECIMAL(19,6)),0) > 0 
				THEN b.mOdds
				ELSE a.odds2 END odds2, --Boost Odds
			CASE WHEN a.statusID = 112 AND ISNULL(TRY_CAST(TRY_CAST(bm.ExtraInfo AS XML).value('(/p1/@bba)[1]', 'VARCHAR(50)') AS DECIMAL(19,6)),0) > 0 
				THEN b.ExtraValue
				ELSE ISNULL(TRY_CAST(TRY_CAST(bm.ExtraInfo AS XML).value('(/p1/@bbp)[1]', 'VARCHAR(50)') AS DECIMAL(19,6)),0) END bbp, --Boost Rate
			ISNULL(TRY_CAST(TRY_CAST(bm.ExtraInfo AS XML).value('(/p1/@bba)[1]', 'VARCHAR(50)') AS DECIMAL(19,6)),0) bba,
			b.stake, b.winlost
		FROM bodb02.dbo.betparlayresult b WITH(NOLOCK) 
			LEFT JOIN bodb02.dbo.bettrans bm WITH (NOLOCK) ON bm.refno = b.RefNo
			LEFT JOIN dbo.rmBettrans a WITH (NOLOCK) ON b.transid = a.transid
		WHERE b.refno = @refno
	
	INSERT INTO #BetParlayDetail(RefNo, Serial, matchid)
		SELECT refno, serial, matchid
		FROM bodb02.dbo.betParlayDetail WITH(NOLOCK)
		WHERE refno = @refno
	
	INSERT INTO #tmpMatch
		SELECT
			p.serial,
			homeid,
			awayid
		FROM #tmpResults p 
			INNER JOIN #BetParlayDetail b ON p.Serial = b.Serial
			INNER JOIN bodb02.dbo.match m WITH(NOLOCK) ON b.matchid = m.matchid	
		WHERE p.statusid <> 113
		UNION 
		SELECT
			p.serial,
			homeid,
			awayid
		FROM #tmpResults p 
			INNER JOIN #BetParlayDetail b ON p.Serial = b.Serial
			INNER JOIN bodb02.dbo.match14 m WITH(NOLOCK) ON b.matchid = m.matchid	
		WHERE p.statusid <> 113
	
	SELECT @outStanding = stake
	FROM rmBettrans WITH(NOLOCK) 
	WHERE matchid = 29  
		AND refno = @refno
	
	SELECT @outStanding = @outStanding - ISNULL(SUM(stake),0)
	FROM #tmpResults
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
						WHEN 112 THEN 'WON' 
						WHEN 113 THEN 'LOSE'
						WHEN 0 THEN 'RUNNING'
						WHEN 1 THEN 'WAITING'
						ELSE '' END AS status,
		modds,
		IsBoostBonus,
		odds OriginalOdds,
		odds2 BoostOdds,
		bbp BoostRate,
		bba,
		stake,
		winlost - stake AS winlost
	FROM #tmpResults
	ORDER BY winlostdate ASC
	
	SELECT * FROM #tmpMatch

	DROP TABLE #BetParlayDetail
	DROP TABLE #tmpMatch
	DROP TABLE #tmpResults
	
END
GO
