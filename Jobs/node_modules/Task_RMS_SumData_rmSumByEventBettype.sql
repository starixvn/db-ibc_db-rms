/*<info serverAlias="DBRMS-bodb_RMS" isFunction="0" isNested="1"></info>*/
ALTER PROCEDURE [dbo].[Task_RMS_SumData_rmSumByEventBettype]
	@winlostdate	SMALLDATETIME
	,@ErrCode		INT = 0 OUTPUT
	,@ErrMsg		VARCHAR(4000) = '' OUTPUT
AS

/*
	Created: 20231228@Cherry
	DB: DBRMS-bodb_RMS
	Task: RMS - Sum data of rmSumByEventBettype

	Revisions:
		- 20231228@Cherry: Initialize SP [RedmineID: #197684]
		- 20241030@Cherry: Add Single Match Parlay (#209293)
		- 20250212@Cherry: hot fix (#217757)
		- 20250214@Cherry: Support direct member (#215427)
		- 20250310@Cherry: Get Selection type of SMP (#214662)
		- 20251016@Cherry: Move sites NovaCasino, SEAL888 from Deposit to Credit (#241763)

*/

BEGIN
	SET NOCOUNT ON

	DECLARE @WLDate DATE
	SELECT  @WLDate = @winlostdate

	DECLARE @MBBU TABLE (BalanceUpDay SMALLDATETIME, MoveBetsDay SMALLDATETIME)
	INSERT INTO @MBBU (BalanceUpDay, MoveBetsDay)
	EXEC bodb02.dbo.Age_SelBalanceUpDay

	DECLARE @BalanceUpDay SMALLDATETIME, @MoveBetsDay SMALLDATETIME
	SELECT  @BalanceUpDay = BalanceUpDay, @MoveBetsDay = MoveBetsDay FROM @MBBU

	IF @winlostdate < @BalanceUpDay
		RETURN

	CREATE TABLE #rmSumByEventBettype
	(
		bettype				SMALLINT
		,ParlayType			TINYINT
		,LeagueId			INT
		,MatchId			INT
		,Betteam			NVARCHAR(10)
		,IsDeposit			BIT
		,TransList			VARBINARY(MAX)
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

	CREATE TABLE #bettrans (transid BIGINT, refno BIGINT, bettype INT, ParlayType TINYINT, IsDeposit BIT, statusID TINYINT, TotalSelection SMALLMONEY, stake MONEY, winloss MONEY, playercomm MONEY, HouseWinloss MONEY)
	CREATE TABLE #bettransm (refno BIGINT, bettype SMALLINT, leagueid INT, matchid INT, betteam NVARCHAR(10), statusID TINYINT)

	IF @winlostdate > @MoveBetsDay
	BEGIN
		INSERT INTO #bettrans (transid, refno, bettype, ParlayType, IsDeposit, statusID, TotalSelection, stake, winloss, playercomm, HouseWinloss)
		SELECT transid, 
			CASE WHEN r.bettype = 29 THEN r.refno
				 WHEN r.bettype = 38 THEN r.transid
			END refno, 
			bettype,
			CASE WHEN bettype = 38 THEN 4 --Single Match Parlay
				WHEN betteam = N'1' THEN 2 --Mix Parlay
				ELSE 3 --Combo Parlay
			END ParlayType, 
			CASE WHEN s.Site IN ('Saba789','NovaCasino','SEAL888') THEN 0 ELSE s.isDeposit END, statusID, hdp2,
			stake*actualrate,(winlost-actual_stake)*actualrate, playercomm*actualrate, 
			CASE WHEN tpositiontaking = 1 THEN 0 ELSE (-(winlost-actual_stake)*(1-tpositiontaking-CAST(ISNULL(epositiontaking, 0) AS DECIMAL(9,8)))-scomm+scomm*CAST(ISNULL(epositiontaking, 0) AS DECIMAL(9,8))/(1 - tpositiontaking))*actualrate END
		FROM dbo.rmBettrans r WITH (NOLOCK)
			INNER JOIN bodb02.dbo.Customer c WITH (NOLOCK) ON r.custid = c.custid
			INNER JOIN bodb02.dbo.Site s WITH (NOLOCK) ON c.site = s.site
		WHERE r.winlostdate = @winlostdate
			AND r.bettype IN (29,38)
			AND r.liveawayscore IN (1,2, 3) -- soccer
			AND r.statusID IN (111, 112, 113, 101, 102)
			AND r.currency <> 20
	END
	ELSE
	BEGIN
		INSERT INTO #bettrans (transid, refno, bettype, ParlayType, IsDeposit, statusID, TotalSelection, stake, winloss, playercomm, HouseWinloss)
		SELECT r.transid, 
			CASE WHEN r.bettype = 29 THEN r.refno
				 WHEN r.bettype = 38 THEN r.transid
			END refno,  
			r.bettype, 
			CASE WHEN r.bettype = 38 THEN 4 --Single Match Parlay
				WHEN r.betteam = N'1' THEN 2 --Mix Parlay
				ELSE 3 --Combo Parlay
			END ParlayType, 
			CASE WHEN s.Site IN ('Saba789','NovaCasino','SEAL888') THEN 0 ELSE s.isDeposit END, 
			r.statusID, r.hdp2, r.stake*r.actualrate, (r.winlost-r.actual_stake)*r.actualrate, r.playercomm*r.actualrate, 
			CASE WHEN r.tpositiontaking = 1 THEN 0 ELSE (-(r.winlost-r.actual_stake)*(1-r.tpositiontaking-CAST(ISNULL(r.epositiontaking, 0) AS DECIMAL(9,8)))-r.scomm+r.scomm*CAST(ISNULL(r.epositiontaking, 0) AS DECIMAL(9,8))/(1 - r.tpositiontaking))*r.actualrate END
		FROM dbo.rmBettrans_Old r WITH (NOLOCK)
			INNER JOIN bodb02.dbo.Customer c WITH (NOLOCK) ON r.custid = c.custid
			INNER JOIN bodb02.dbo.Site s WITH (NOLOCK) ON c.site = s.site
			LEFT JOIN #bettrans b ON r.transid = b.transid
		WHERE r.winlostdate = @winlostdate
			AND r.bettype IN (29,38)
			AND r.liveawayscore IN (1, 2, 3) -- soccer
			AND r.statusID IN (111, 112, 113, 101, 102)
			AND r.currency <> 20
			AND b.transid IS NULL
	END		
       
	INSERT INTO #bettransm (refno, bettype, leagueid, matchid, betteam, statusID)
    SELECT bm.refno, bm.bettype, m.leagueid,  bm.matchId, bm.betteam,bm.statusID				
	FROM bodb02.dbo.bettransm bm WITH (NOLOCK)
		INNER JOIN bodb02.dbo.match m WITH (NOLOCK) ON bm.matchid = m.matchid
	WHERE m.sporttype IN (1,2) AND (bm.winlostdate > @MoveBetsDay OR bm.winlostdate IS NULL)
		AND bm.refno IN (SELECT refno FROM #bettrans WHERE bettype = 29)
	
	INSERT INTO #bettransm (refno, bettype, leagueid, matchid, betteam, statusID)
	SELECT bm.refno, bm.bettype, m.leagueid, bm.matchId,bm.betteam, bm.statusID 	
	FROM bodb02.dbo.bettransm14 bm WITH (NOLOCK)
		INNER JOIN bodb02.dbo.match14 m WITH (NOLOCK) ON bm.matchid = m.matchid
	WHERE m.sporttype IN (1,2) AND bm.winlostdate BETWEEN @BalanceUpDay AND @MoveBetsDay
		AND bm.refno IN (SELECT refno FROM #bettrans WHERE bettype = 29)
	
	INSERT INTO #bettransm (refno, bettype, leagueid, matchid, betteam, statusID)
	SELECT bm.refno, bm.bettype, m.leagueid, bm.matchId,bm.betteam, bm.statusID 				
	FROM dbo.rmBettransm_bk bm WITH (NOLOCK)
		INNER JOIN dbo.rmMatch_bk m WITH (NOLOCK) ON bm.matchid = m.matchid
	WHERE m.sporttype IN (1,2) AND bm.winlostdate < @BalanceUpDay
		AND bm.refno IN (SELECT refno FROM #bettrans WHERE bettype = 29)

	INSERT INTO #bettransm (refno, bettype, leagueid, matchid, betteam, statusID)
    SELECT bm.transid, bm.bettype, m.leagueid,  bm.matchId, s.SelectionType betteam,
			CASE WHEN s.Result = 'Won' THEN 112
				 WHEN s.Result = 'Lose' THEN 113
				 WHEN s.Result = 'Draw' THEN 111
			END statusID				
	FROM dbo.rmbettrans bm WITH (NOLOCK)
		INNER JOIN bodb02.dbo.match m WITH (NOLOCK) ON bm.matchid = m.matchid
		INNER JOIN bodb02.dbo.SMP_MarketSelection s WITH(NOLOCK) ON s.MatchId = bm.matchid AND s.MarketId = bm.betcheck
	WHERE m.sporttype IN (1,2) AND (bm.winlostdate > @MoveBetsDay OR bm.winlostdate IS NULL)
		AND bm.transid IN (SELECT transid FROM #bettrans WHERE bettype = 38)
	
	INSERT INTO #bettransm (refno, bettype, leagueid, matchid, betteam, statusID)
	SELECT bm.transid, bm.bettype, m.leagueid, bm.matchId,s.SelectionType betteam, 
			CASE WHEN s.Result = 'Won' THEN 112
				 WHEN s.Result = 'Lose' THEN 113
				 WHEN s.Result = 'Draw' THEN 111
			END statusID
	FROM dbo.rmBettrans_Old bm WITH (NOLOCK)
		INNER JOIN bodb02.dbo.match14 m WITH (NOLOCK) ON bm.matchid = m.matchid
		INNER JOIN bodb02.dbo.SMP_MarketSelection14 s WITH(NOLOCK) ON s.MatchId = bm.matchid AND s.MarketId = bm.betcheck
	WHERE m.sporttype IN (1,2) AND bm.winlostdate BETWEEN @BalanceUpDay AND @MoveBetsDay
		AND bm.transid IN (SELECT transid FROM #bettrans WHERE bettype = 38)
      
    CREATE CLUSTERED INDEX CIX_bettrans_transid ON #bettrans (transid)
    CREATE NONCLUSTERED INDEX CIX_bettrans_refno ON #bettrans (refno)
    CREATE CLUSTERED INDEX CIX_bettransm ON #bettransm (refno)

	CREATE TABLE #tmp1 (refno BIGINT, bettype SMALLINT, leagueid INT, matchid INT, betteam NVARCHAR(10), statusID TINYINT, RowNum BIGINT)
	INSERT INTO #tmp1 (refno, bettype, leagueid, matchid, betteam, statusID, RowNum)
	SELECT refno, bettype, LeagueId, matchId, betteam, statusID, 			
			ROW_NUMBER() OVER(PARTITION BY refno, bettype, LeagueId, matchId, betteam ORDER BY (SELECT NULL)) AS RowNum
	FROM  #bettransm

	CREATE CLUSTERED INDEX CIX_tmp1 ON #tmp1 (refno)

	BEGIN
		INSERT INTO #rmSumByEventBettype (bettype, ParlayType, LeagueId, MatchId, Betteam, IsDeposit, TransList, BetCount, WonCount, LoseCount, DrawCount, MainBetCount, MainWonCount, MainLoseCount, MainDrawCount, MainStake, MainTurnover, MainTurnoverNoDraw, MainMemberWinloss, MainMemberComm, MainHouseWinloss)
		SELECT
			t.bettype,
			b.ParlayType,
			t.LeagueId,
			t.matchid,
			t.betteam,
			b.IsDeposit,
            COMPRESS((SELECT STRING_AGG(CASE WHEN b.statusID = 112 THEN CAST(b.transid AS VARCHAR(MAX)) 
							ELSE NULL END
						, ',') AS 'tl'
							 FOR JSON PATH
							,INCLUDE_NULL_VALUES))  TransList,
			BetCount			= SUM(1),
			WonCount			= SUM(CASE WHEN t.statusID = 112 THEN 1 ELSE 0 END),
			LoseCount			= SUM(CASE WHEN t.statusID = 113 THEN 1 ELSE 0 END),
			DrawCount			= SUM(CASE WHEN t.statusID = 111 THEN 1 ELSE 0 END),
			MainBetCount		= SUM(CASE WHEN t.rn = 1 THEN 1 ELSE 0 END),
			MainWonCount		= SUM(CASE WHEN t.rn = 1 AND b.statusID = 112 THEN 1 ELSE 0 END),
			MainLoseCount		= SUM(CASE WHEN t.rn = 1 AND b.statusID = 113 THEN 1 ELSE 0 END),
			MainDrawCount		= SUM(CASE WHEN t.rn = 1 AND b.statusID = 111 THEN 1 ELSE 0 END),
			MainStake			= SUM(CASE WHEN t.rn = 1 THEN CASE WHEN ISNULL(b.TotalSelection,0) = 0 THEN 0 ELSE b.stake/b.TotalSelection END ELSE 0 END),
			MainTurnover		= SUM(CASE WHEN t.rn = 1 AND b.statusID IN (111, 112, 113) THEN CASE WHEN ISNULL(b.TotalSelection,0) = 0 THEN 0 ELSE b.stake/b.TotalSelection END ELSE 0 END),
			MainTurnoverNoDraw	= SUM(CASE WHEN t.rn = 1 AND b.statusID IN (112, 113) THEN CASE WHEN ISNULL(b.TotalSelection,0) = 0 THEN 0 ELSE b.stake/b.TotalSelection END ELSE 0 END),
			MainWinloss			= SUM(CASE WHEN t.rn = 1 THEN CASE WHEN ISNULL(b.TotalSelection,0) = 0 THEN 0 ELSE b.winloss/b.TotalSelection END ELSE 0 END),
			MainComm			= SUM(CASE WHEN t.rn = 1 THEN CASE WHEN ISNULL(b.TotalSelection,0) = 0 THEN 0 ELSE b.playercomm/b.TotalSelection END ELSE 0 END),
			MainHouseWinloss	= SUM(CASE WHEN t.rn = 1 THEN CASE WHEN ISNULL(b.TotalSelection,0) = 0 THEN 0 ELSE b.HouseWinloss/b.TotalSelection END ELSE 0 END)
		FROM #bettrans b
			CROSS APPLY (
				SELECT bettype, LeagueId, matchId, betteam, statusID, RowNum AS rn			
				FROM  #tmp1 bm
                WHERE b.refno = bm.refno
			) t
		GROUP BY
			t.bettype,
			b.ParlayType,
			b.IsDeposit,
			t.LeagueId,
			t.matchid,
			t.betteam				
			
		CREATE TABLE #tmp2 (refno BIGINT, bettype SMALLINT, leagueid INT, matchid INT, statusID TINYINT, RowNum BIGINT)
		INSERT INTO #tmp2 (refno, bettype, leagueid, matchid, statusID, RowNum)
		SELECT refno, bettype, LeagueId, matchId, statusID, 			
				ROW_NUMBER() OVER(PARTITION BY refno, bettype, LeagueId, matchId ORDER BY (SELECT NULL)) AS RowNum
		FROM  #bettransm	

		CREATE CLUSTERED INDEX CIX_tmp2 ON #tmp2 (refno)

		-- SMP sum by Event
		INSERT INTO #rmSumByEventBettype (bettype, ParlayType, LeagueId, MatchId, Betteam, IsDeposit, TransList, BetCount, WonCount, LoseCount, DrawCount, MainBetCount, MainWonCount, MainLoseCount, MainDrawCount, MainStake, MainTurnover, MainTurnoverNoDraw, MainMemberWinloss, MainMemberComm, MainHouseWinloss)
		SELECT t.bettype,
			b.ParlayType,
			t.leagueid,
			t.matchid, 
			'0' betteam,
			b.IsDeposit,
			COMPRESS((SELECT STRING_AGG(CASE WHEN b.statusID = 112 THEN CAST(b.transid AS VARCHAR(MAX)) 
							ELSE NULL END
						, ',') AS 'tl'
							 FOR JSON PATH
							,INCLUDE_NULL_VALUES))  TransList,
			BetCount			= SUM(1),
			WonCount			= SUM(CASE WHEN t.statusID = 112 THEN 1 ELSE 0 END),
			LoseCount			= SUM(CASE WHEN t.statusID = 113 THEN 1 ELSE 0 END),
			DrawCount			= SUM(CASE WHEN t.statusID = 111 THEN 1 ELSE 0 END),
			MainBetCount		= SUM(CASE WHEN t.rn = 1 THEN 1 ELSE 0 END),
			MainWonCount		= SUM(CASE WHEN t.rn = 1 AND b.statusID = 112 THEN 1 ELSE 0 END),
			MainLoseCount		= SUM(CASE WHEN t.rn = 1 AND b.statusID = 113 THEN 1 ELSE 0 END),
			MainDrawCount		= SUM(CASE WHEN t.rn = 1 AND b.statusID = 111 THEN 1 ELSE 0 END),
			MainStake			= SUM(CASE WHEN ISNULL(b.TotalSelection,0) = 0 THEN 0 ELSE b.stake/b.TotalSelection END),
			MainTurnover		= SUM(CASE WHEN b.statusID IN (111, 112, 113) THEN CASE WHEN ISNULL(b.TotalSelection,0) = 0 THEN 0 ELSE b.stake/b.TotalSelection END ELSE 0 END),
			MainTurnoverNoDraw	= SUM(CASE WHEN b.statusID IN (112, 113) THEN CASE WHEN ISNULL(b.TotalSelection,0) = 0 THEN 0 ELSE b.stake/b.TotalSelection END ELSE 0 END),
			MainWinloss			= SUM(CASE WHEN ISNULL(b.TotalSelection,0) = 0 THEN 0 ELSE b.winloss/b.TotalSelection END),
			MainComm			= SUM(CASE WHEN ISNULL(b.TotalSelection,0) = 0 THEN 0 ELSE b.playercomm/b.TotalSelection END),
			MainHouseWinloss	= SUM(CASE WHEN ISNULL(b.TotalSelection,0) = 0 THEN 0 ELSE b.HouseWinloss/b.TotalSelection END)
		FROM #bettrans b
			CROSS APPLY (
				SELECT bettype, LeagueId, matchId, statusID, RowNum AS rn		
				FROM  #tmp2 bm
                WHERE b.refno = bm.refno
			) t 
		WHERE b.bettype = 38
		GROUP BY t.bettype,
			b.ParlayType,
			t.leagueid,
			t.matchid, 
			b.IsDeposit
		-- End SMP
	END

	BEGIN TRY
		DELETE dbo.rmSumByEventBettype WITH (ROWLOCK, UPDLOCK) WHERE winlostdate = @WLDate

		INSERT INTO dbo.rmSumByEventBettype (winlostdate,bettype,ParlayType,leagueId,matchId,betteam,IsDeposit,TransList,BetCount,WonCount,DrawCount,LoseCount,MainBetCount,MainWonCount,MainLoseCount,MainDrawCount,MainStake,MainTurnover,MainTurnoverNoDraw,MainMemberWinloss,MainMemberComm,MainHouseWinloss)
		SELECT @WLDate,bettype,ParlayType,leagueId,matchId,betteam,IsDeposit,TransList,
			SUM(BetCount),SUM(WonCount),SUM(DrawCount),SUM(LoseCount),
			SUM(MainBetCount),SUM(MainWonCount),SUM(MainLoseCount),SUM(MainDrawCount),
			SUM(MainStake),SUM(MainTurnover),SUM(MainTurnoverNoDraw),
			SUM(MainMemberWinloss),SUM(MainMemberComm),SUM(MainHouseWinloss)
		FROM #rmSumByEventBettype 
		GROUP BY bettype,ParlayType,leagueId,matchId,betteam,IsDeposit,TransList

	END TRY
	BEGIN CATCH
		SELECT @ErrCode = ERROR_NUMBER(), @ErrMsg = ERROR_MESSAGE()
	END CATCH

	DROP TABLE #rmSumByEventBettype
	DROP TABLE #bettrans
	DROP TABLE #bettransm
	DROP TABLE #tmp1
	DROP TABLE #tmp2

END
GO