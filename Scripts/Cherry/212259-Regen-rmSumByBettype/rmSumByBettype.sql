/*<info serverAlias="DBRMS-bodb_RMS" isFunction="0" isNested="1"></info>*/
-- Regen rmSumByBettype
	SET NOCOUNT ON

	DECLARE @winlostdate DATE
    SELECT  @winlostdate = DATEADD(DAY,-1,GETDATE())

	DECLARE @MBBU TABLE (BalanceUpDay SMALLDATETIME, MoveBetsDay SMALLDATETIME)
	INSERT INTO @MBBU (BalanceUpDay, MoveBetsDay)
	EXEC bodb02.dbo.Age_SelBalanceUpDay

	DECLARE @BalanceUpDay SMALLDATETIME, @MoveBetsDay SMALLDATETIME
	SELECT  @BalanceUpDay = BalanceUpDay, @MoveBetsDay = MoveBetsDay FROM @MBBU

	CREATE TABLE #rmSumByBettype
	(
		bettype				SMALLINT
		,ParlayType			TINYINT
		,IsDeposit			BIT
		,leagueId			INT
		,BetCount			INT
		,WonCount			INT
		,LoseCount			INT
		,DrawCount			INT
		,MainBetCount		INT
		,MainWonCount		INT
		,MainLoseCount		INT
		,MainDrawCount		INT
		,MainStake			MONEY
		,MainTurnover		MONEY
		,MainTurnoverNoDraw	MONEY
		,MainMemberWinloss	MONEY
		,MainMemberComm		MONEY
		,MainHouseWinloss	MONEY
	)
	CREATE CLUSTERED INDEX CIX_rmSumByBettype ON #rmSumByBettype (bettype, ParlayType)

	CREATE TABLE #bettrans(refno BIGINT, ParlayType TINYINT, IsDeposit BIT, statusID TINYINT, TotalSelection SMALLMONEY, stake MONEY, winloss MONEY, playercomm MONEY, HouseWinloss MONEY)
    
    CREATE UNIQUE CLUSTERED INDEX IX_bettrans ON #bettrans (refno)

    CREATE TABLE #match (refno BIGINT, sporttype INT, bettype INT ,leagueid INT, matchid INT, statusID TINYINT, winlostdate SMALLDATETIME)
    
    CREATE CLUSTERED INDEX IX_match ON #match (refno, sporttype)

    DECLARE @EndDate DATE
    SELECT @EndDate = MIN(winlostdate)
    FROM dbo.rmBettrans_Old r WITH (NOLOCK)
   
WHILE @winlostdate >= @EndDate
BEGIN
	IF @winlostdate > @MoveBetsDay
	BEGIN
		INSERT INTO #bettrans (refno, ParlayType, IsDeposit, statusID, TotalSelection, stake, winloss, playercomm, HouseWinloss)
		SELECT refno, CASE WHEN betteam = N'1' THEN 2 ELSE 3 END, CASE WHEN s.Site = 'Saba789' THEN 0 ELSE s.isDeposit END, statusID, hdp2, 
			stake*actualrate, (winlost-actual_stake)*actualrate, playercomm*actualrate, 
		CASE WHEN tpositiontaking = 1 THEN 0 ELSE (-(winlost-actual_stake)*(1-tpositiontaking-CAST(ISNULL(epositiontaking, 0) AS DECIMAL(9,8)))-scomm+scomm*CAST(ISNULL(epositiontaking, 0) AS DECIMAL(9,8))/(1 - tpositiontaking))*actualrate END
		FROM dbo.rmBettrans r WITH (NOLOCK)
			INNER JOIN bodb02.dbo.Customer c WITH (NOLOCK) ON r.recommend = c.custid
			INNER JOIN bodb02.dbo.Site s WITH (NOLOCK) ON c.site = s.site
		WHERE r.winlostdate = @winlostdate
			AND r.bettype = 29
			AND r.liveawayscore IN (1,2, 3) -- soccer
			AND r.statusID IN (111, 112, 113, 101, 102)
			AND r.currency <> 20
	END
	ELSE
	BEGIN
		INSERT INTO #bettrans (refno, ParlayType, IsDeposit, statusID, TotalSelection, stake, winloss, playercomm, HouseWinloss)
		SELECT refno, CASE WHEN betteam = N'1' THEN 2 ELSE 3 END, CASE WHEN s.Site = 'Saba789' THEN 0 ELSE s.isDeposit END, 
			statusID, hdp2, stake*actualrate, (winlost-actual_stake)*actualrate, playercomm*actualrate, 
		CASE WHEN tpositiontaking = 1 THEN 0 ELSE (-(winlost-actual_stake)*(1-tpositiontaking-CAST(ISNULL(epositiontaking, 0) AS DECIMAL(9,8)))-scomm+scomm*CAST(ISNULL(epositiontaking, 0) AS DECIMAL(9,8))/(1 - tpositiontaking))*actualrate END
		FROM dbo.rmBettrans_Old r WITH (NOLOCK)
			INNER JOIN bodb02.dbo.Customer c WITH (NOLOCK) ON r.recommend = c.custid
			INNER JOIN bodb02.dbo.Site s WITH (NOLOCK) ON c.site = s.site
		WHERE r.winlostdate = @winlostdate
			AND r.bettype = 29
			AND r.liveawayscore IN (1, 2, 3) -- soccer
			AND r.statusID IN (111, 112, 113, 101, 102)
			AND r.currency <> 20
	END    

    INSERT INTO #match (refno, sporttype, bettype, leagueid, matchid, statusID, winlostdate)
    SELECT refno, sporttype, bm.bettype, m.leagueid, m.matchid, bm.statusID, winlostdate
    FROM bodb02.dbo.bettransm bm WITH (NOLOCK)
        INNER JOIN bodb02.dbo.match m WITH (NOLOCK) ON bm.matchid = m.matchid
    WHERE m.sporttype IN (1,2) AND (bm.winlostdate > @MoveBetsDay OR bm.winlostdate IS NULL)
      AND refno IN (SELECT refno FROM #bettrans)

    INSERT INTO #match (refno, sporttype, bettype, leagueid, matchid, statusID, winlostdate)
    SELECT refno, sporttype, bm.bettype, m.leagueid, m.matchid, bm.statusID, winlostdate
    FROM bodb02.dbo.bettransm14 bm WITH (NOLOCK)
        INNER JOIN bodb02.dbo.match14 m WITH (NOLOCK) ON bm.matchid = m.matchid
    WHERE m.sporttype IN (1,2) AND bm.winlostdate BETWEEN @BalanceUpDay AND  @MoveBetsDay
      AND refno IN (SELECT refno FROM #bettrans)

	--assist param to guide better plan (avoid index scan of rmBettrans_bk)
	DECLARE @minRef BIGINT
    SELECT @minRef = MIN(refno) FROM #bettrans

    INSERT INTO #match (refno, sporttype, bettype, leagueid, matchid, statusID, winlostdate)
    SELECT refno, sporttype, bm.bettype, m.leagueid, bm.matchid, bm.statusID, winlostdate
    FROM dbo.rmBettransm_bk bm WITH (NOLOCK)
        INNER JOIN dbo.rmMatch_bk m WITH (NOLOCK) ON bm.matchid = m.matchid
    WHERE m.sporttype IN (1,2) AND bm.winlostdate < @BalanceUpDay
      AND refno IN (SELECT refno FROM #bettrans)
	  AND refno >= @minRef   

	BEGIN
		INSERT INTO #rmSumByBettype (bettype, ParlayType, IsDeposit, LeagueId, BetCount, WonCount, LoseCount, DrawCount, MainBetCount, MainWonCount, MainLoseCount, MainDrawCount, MainStake, MainTurnover, MainTurnoverNoDraw, MainMemberWinloss, MainMemberComm, MainHouseWinloss)
		SELECT
			t.bettype
			,b.ParlayType
			,b.IsDeposit
			,t.LeagueId
			,BetCount			= SUM(1)
			,WonCount			= SUM(CASE WHEN t.statusID = 112 THEN 1 ELSE 0 END)
			,LoseCount			= SUM(CASE WHEN t.statusID = 113 THEN 1 ELSE 0 END)
			,DrawCount			= SUM(CASE WHEN t.statusID = 111 THEN 1 ELSE 0 END)
			,MainBetCount		= SUM(CASE WHEN t.rn = 1 THEN 1 ELSE 0 END)
			,MainWonCount		= SUM(CASE WHEN t.rn = 1 AND b.statusID = 112 THEN 1 ELSE 0 END)
			,MainLoseCount		= SUM(CASE WHEN t.rn = 1 AND b.statusID = 113 THEN 1 ELSE 0 END)
			,MainDrawCount		= SUM(CASE WHEN t.rn = 1 AND b.statusID = 111 THEN 1 ELSE 0 END)
			,MainStake			= SUM(CASE WHEN t.rn = 1 THEN CASE WHEN ISNULL(b.TotalSelection,0) = 0 THEN 0 ELSE b.stake/b.TotalSelection END ELSE 0 END)
			,MainTurnover		= SUM(CASE WHEN t.rn = 1 AND b.statusID IN (111, 112, 113) THEN CASE WHEN ISNULL(b.TotalSelection,0) = 0 THEN 0 ELSE b.stake/b.TotalSelection END ELSE 0 END)
			,MainTurnoverNoDraw	= SUM(CASE WHEN t.rn = 1 AND b.statusID IN (112, 113) THEN CASE WHEN ISNULL(b.TotalSelection,0) = 0 THEN 0 ELSE b.stake/b.TotalSelection END ELSE 0 END)
			,MainWinloss		= SUM(CASE WHEN t.rn = 1 THEN CASE WHEN ISNULL(b.TotalSelection,0) = 0 THEN 0 ELSE b.winloss/b.TotalSelection END ELSE 0 END)
			,MainComm			= SUM(CASE WHEN t.rn = 1 THEN CASE WHEN ISNULL(b.TotalSelection,0) = 0 THEN 0 ELSE b.playercomm/b.TotalSelection END ELSE 0 END) 
			,MainHouseWinloss	= SUM(CASE WHEN t.rn = 1 THEN CASE WHEN ISNULL(b.TotalSelection,0) = 0 THEN 0 ELSE b.HouseWinloss/b.TotalSelection END ELSE 0 END)
		FROM #bettrans b
			CROSS APPLY (
				SELECT bettype, LeagueId, statusID, ROW_NUMBER() OVER(PARTITION BY bettype, LeagueId, matchid ORDER BY (SELECT NULL)) AS rn
				FROM #match
                WHERE b.refno = #match.refno
			) t
		GROUP BY
			t.bettype
			,b.ParlayType
			,b.IsDeposit
			,t.LeagueId

		-- Total
		INSERT INTO #rmSumByBettype (bettype, ParlayType, IsDeposit, LeagueId, BetCount, WonCount, LoseCount, DrawCount, MainBetCount, MainWonCount, MainLoseCount, MainDrawCount, MainStake, MainTurnover, MainTurnoverNoDraw, MainMemberWinloss, MainMemberComm, MainHouseWinloss)
		SELECT
			t.bettype
			,b.ParlayType
			,b.IsDeposit
			,0  -- soccer only
			,BetCount			= SUM(1)
			,WonCount			= SUM(CASE WHEN t.statusID = 112 THEN 1 ELSE 0 END)
			,LoseCount			= SUM(CASE WHEN t.statusID = 113 THEN 1 ELSE 0 END)
			,DrawCount			= SUM(CASE WHEN t.statusID = 111 THEN 1 ELSE 0 END)
			,MainBetCount		= SUM(CASE WHEN t.rn = 1 THEN 1 ELSE 0 END)
			,MainWonCount		= SUM(CASE WHEN t.rn = 1 AND b.statusID = 112 THEN 1 ELSE 0 END)
			,MainLoseCount		= SUM(CASE WHEN t.rn = 1 AND b.statusID = 113 THEN 1 ELSE 0 END)
			,MainDrawCount		= SUM(CASE WHEN t.rn = 1 AND b.statusID = 111 THEN 1 ELSE 0 END)
			,MainStake			= SUM(CASE WHEN t.rn = 1 THEN CASE WHEN ISNULL(b.TotalSelection,0) = 0 THEN 0 ELSE b.stake/b.TotalSelection END ELSE 0 END)
			,MainTurnover		= SUM(CASE WHEN t.rn = 1 AND b.statusID IN (111, 112, 113) THEN CASE WHEN ISNULL(b.TotalSelection,0) = 0 THEN 0 ELSE b.stake/b.TotalSelection END ELSE 0 END)
			,MainTurnoverNoDraw	= SUM(CASE WHEN t.rn = 1 AND b.statusID IN (112, 113) THEN CASE WHEN ISNULL(b.TotalSelection,0) = 0 THEN 0 ELSE b.stake/b.TotalSelection END ELSE 0 END)
			,MainWinloss		= SUM(CASE WHEN t.rn = 1 THEN CASE WHEN ISNULL(b.TotalSelection,0) = 0 THEN 0 ELSE b.winloss/b.TotalSelection END ELSE 0 END)
			,MainComm			= SUM(CASE WHEN t.rn = 1 THEN CASE WHEN ISNULL(b.TotalSelection,0) = 0 THEN 0 ELSE b.playercomm/b.TotalSelection END ELSE 0 END) 
			,MainHouseWinloss	= SUM(CASE WHEN t.rn = 1 THEN CASE WHEN ISNULL(b.TotalSelection,0) = 0 THEN 0 ELSE b.HouseWinloss/b.TotalSelection END ELSE 0 END)
		FROM #bettrans b
			CROSS APPLY (
				SELECT refno, bettype, statusID, ROW_NUMBER() OVER(PARTITION BY bettype, matchid ORDER BY (SELECT NULL)) AS rn
				FROM #match
                WHERE #match.sporttype = 1
                  AND #match.winlostdate IS NOT NULL
				  AND b.refno = #match.refno
			) t                
		GROUP BY
			t.bettype
			,b.ParlayType
			,b.IsDeposit
	END

	BEGIN 
		DELETE dbo.rmSumByBettype WITH (ROWLOCK, UPDLOCK) WHERE winlostdate = @winlostdate

		INSERT INTO dbo.rmSumByBettype (winlostdate,bettype,ParlayType,IsDeposit,leagueId,BetCount,WonCount,DrawCount,LoseCount,MainBetCount,MainWonCount,MainLoseCount,MainDrawCount,MainStake,MainTurnover,MainTurnoverNoDraw,MainMemberWinloss,MainMemberComm,MainHouseWinloss)
		SELECT @winlostdate,bettype,ParlayType,IsDeposit,leagueId,SUM(BetCount),SUM(WonCount),SUM(DrawCount),SUM(LoseCount),SUM(MainBetCount),SUM(MainWonCount),SUM(MainLoseCount),SUM(MainDrawCount),SUM(MainStake),SUM(MainTurnover),SUM(MainTurnoverNoDraw),SUM(MainMemberWinloss),SUM(MainMemberComm),SUM(MainHouseWinloss)        
		FROM #rmSumByBettype
		GROUP BY bettype,ParlayType,IsDeposit,leagueId
	END 
	
	DELETE #rmSumByBettype
    DELETE #bettrans
    DELETE #match
    
    SELECT @winlostdate = DATEADD(DAY,-1,@winlostdate)
END
GO