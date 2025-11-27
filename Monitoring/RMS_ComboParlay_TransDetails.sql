/*<info serverAlias="DBRMS-bodb_RMS" executers="wsv_rms" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[RMS_ComboParlay_TransDetails]
	@transid		BIGINT
	,@refno			BIGINT
	,@CurrencyName	VARCHAR(50) = NULL OUTPUT

AS

/*	
	Created: 20160506@Winnie
	DB: DBRMS-bodb_RMS
	Task: Get details selection of parlay tickets by transid/refno

	Revisions:
		- 20160906@Winnie: Change betlist to support other bettype RedmineID #63648 	
		- 20160926@Winnie: fix issue conflict refno with racing RedmineID: #64286
		- 20191026@Jacob: Show stake on bet details RedmineID: [#122137]
		- 20200510@Percy: Add Penalty Shootout Combo [RedmineID: #133961]
		- 20200821@Percy: Fix issue duplicate data due to MBBU process [RedmineID: #140078]
		- 20210324@Danny: Get data from backup range  [RedmineID: #148137]
		- 20210319@Danny: Incorporate Cricket AIO into PRMS [RedmineID: #151319]
		- 20230320@Cherry: Change formula of Stake (#185251)
		- 20240312@Cherry: Change SQL account in metadata (#202012)
		- 20251020@Cherry: Integrate Hybrid Parlay (#242165)
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @MBU TABLE (BalanceUpDay SMALLDATETIME, MoveBetsDay SMALLDATETIME)
	INSERT INTO @MBU (BalanceUpDay, MoveBetsDay)
	EXEC bodb02.dbo.Age_SelBalanceUpDay

	DECLARE @BalanceUpDay SMALLDATETIME, @MoveBetsDay SMALLDATETIME
	SELECT  @BalanceUpDay = BalanceUpDay, @MoveBetsDay = MoveBetsDay FROM @MBU

	SET @CurrencyName = NULL

	DECLARE @tpositiontaking SMALLMONEY, @actualrate FLOAT, @sql NVARCHAR(MAX), @transdesc NVARCHAR(1000)
	SELECT  @CurrencyName = MAX(CurrencyName), @tpositiontaking = MAX(tpositiontaking), 
			@actualrate = MAX(actualrate), @transdesc = MAX(transdesc)
	FROM
	(
		SELECT CurrencyName, tpositiontaking, actualrate, transdesc
		FROM dbo.rmBettrans WITH (NOLOCK) WHERE transid = @transid
		UNION 
		SELECT CurrencyName, tpositiontaking, actualrate, transdesc
		FROM dbo.rmBettrans_Old WITH (NOLOCK) WHERE transid = @transid
	)m

	-- Blacklist league
	DECLARE @BlacklistLeagueGroupId INT
	SELECT  @BlacklistLeagueGroupId = GroupId FROM dbo.rmLeagueGroup WITH (NOLOCK) WHERE GroupName = 'Blacklist'

	-- get data detail
	DECLARE @bettransm TABLE
	(
		transid BIGINT, bettype SMALLINT, homeid INT, awayid INT, hdp1 SMALLMONEY, hdp2 SMALLMONEY
		,odds SMALLMONEY, betteam NVARCHAR(10), statusID TINYINT, status NVARCHAR(10)
		,livehomescore SMALLINT, liveawayscore SMALLINT, liveindicator BIT
		,leagueid INT, sporttype SMALLINT, isNeutral BIT, matchid INT, matchcode NVARCHAR(50)
		,betstatus NVARCHAR(50), betcheck NVARCHAR(50), stake MONEY, transdate DATETIME, transdesc NVARCHAR(1000)
		,IsBlacklistLeague BIT
	)

	-- bettransm
	IF EXISTS (SELECT 1 FROM bodb02.dbo.bettransm WITH (NOLOCK) WHERE refno = @refno AND (statusID IN (0, 1) OR winlostdate > @MoveBetsDay))
	BEGIN
		INSERT INTO @bettransm
		(
			transid, bettype, homeid, awayid, hdp1, hdp2
			,odds, betteam, statusID, status
			,livehomescore, liveawayscore, liveindicator
			,leagueid, sporttype, isNeutral, matchid, matchcode
			,betstatus, betcheck, stake, transdate, transdesc
			,IsBlacklistLeague
		)
		SELECT
			bm.transid, bm.bettype, m.homeid, m.awayid, bm.hdp1, bm.hdp2
			,bm.odds, bm.betteam, bm.statusID, bm.status
			,bm.livehomescore, bm.liveawayscore, bm.liveindicator
			,m.leagueid, m.sporttype, m.isNeutral, CASE WHEN m.ChildMatchType = 200 THEN m.ParentID else m.matchid END, m.matchcode
			,m.betstatus, bm.betcheck, bm.stake, bm.transdate, bm.transdesc
			,CASE WHEN l.LeagueId IS NOT NULL THEN 1 ELSE 0 END
		FROM bodb02.dbo.bettransm bm WITH (NOLOCK)
			INNER JOIN bodb02.dbo.match m WITH (NOLOCK) ON bm.matchid = m.matchid
			LEFT JOIN dbo.rmLeague l WITH (NOLOCK) ON m.leagueid = l.LeagueId AND l.GroupId = @BlacklistLeagueGroupId
		WHERE refno = @refno
	END

	-- bettransm14
	IF EXISTS (SELECT 1 FROM bodb02.dbo.bettransm14 WITH (NOLOCK) WHERE refno = @refno AND winlostdate BETWEEN @BalanceUpDay AND @MoveBetsDay)
	BEGIN
		INSERT INTO @bettransm
		(
			transid, bettype, homeid, awayid, hdp1, hdp2
			,odds, betteam, statusID, status
			,livehomescore, liveawayscore, liveindicator
			,leagueid, sporttype, isNeutral, matchid, matchcode
			,betstatus, betcheck, stake, transdate, transdesc
			,IsBlacklistLeague
		)
		SELECT
			bm.transid, bm.bettype, m.homeid, m.awayid, bm.hdp1, bm.hdp2
			,bm.odds, bm.betteam, bm.statusID, bm.status
			,bm.livehomescore, bm.liveawayscore, bm.liveindicator
			,m.leagueid, m.sporttype, m.isNeutral,  CASE WHEN m.ChildMatchType = 200 THEN m.ParentID else m.matchid END, m.matchcode
			,m.betstatus, bm.betcheck, bm.stake, bm.transdate, bm.transdesc
			,CASE WHEN l.LeagueId IS NOT NULL THEN 1 ELSE 0 END
		FROM bodb02.dbo.bettransm14 bm WITH (NOLOCK)
			INNER JOIN bodb02.dbo.match14 m WITH (NOLOCK) ON bm.matchid = m.matchid
			LEFT JOIN dbo.rmLeague l WITH (NOLOCK) ON m.leagueid = l.LeagueId AND l.GroupId = @BlacklistLeagueGroupId
		WHERE refno = @refno
	END

	-- bettrans_bk
	IF EXISTS (SELECT 1 FROM DBARC.bodb_Archive.dbo.bettransm WITH (NOLOCK) WHERE refno = @refno AND winlostdate < @BalanceUpDay)
	BEGIN
		SELECT @sql = 'SELECT transid,bettype,homeid,awayid,hdp1,hdp2,odds,betteam,statusid
							,status,livehomescore,liveawayscore,liveindicator,leagueid,sporttype
							,isNeutral,matchid,matchcode,betstatus,betcheck,stake,transdate,transdesc
						FROM OPENQUERY(DBARC, ''SELECT bm.transid,bm.bettype,m.homeid,m.awayid,bm.hdp1,bm.hdp2,bm.odds,bm.betteam,bm.statusid
														,bm.status,bm.livehomescore,bm.liveawayscore,bm.liveindicator,m.leagueid,m.sporttype
														,m.isNeutral, CASE WHEN m.ChildMatchType = 200 THEN m.ParentID else m.matchid END matchid,m.matchcode,m.betstatus,bm.betcheck,bm.stake ,bm.transdate, bm.transdesc
												FROM bodb_Archive.dbo.bettransm bm WITH (NOLOCK)
													INNER JOIN bodb_Archive.dbo.match_bk m WITH (NOLOCK) ON bm.matchid = m.matchid
												WHERE bm.refno = ' + CONVERT(VARCHAR(50), @refno) + ''')'

		
		INSERT INTO @bettransm
		(
			transid, bettype, homeid, awayid, hdp1, hdp2
			,odds, betteam, statusID, status
			,livehomescore, liveawayscore, liveindicator
			,leagueid, sporttype, isNeutral, matchid, matchcode
			,betstatus, betcheck, stake, transdate, transdesc
		)
        EXECUTE sp_executesql @sql

		UPDATE m
		SET m.IsBlacklistLeague = CASE WHEN l.LeagueId IS NOT NULL THEN 1 ELSE 0 END
		FROM @bettransm m 
		LEFT JOIN dbo.rmLeague l WITH (NOLOCK) ON m.leagueid = l.LeagueId AND l.GroupId = @BlacklistLeagueGroupId
	END

	-- Return data
	SELECT
		transid,bettype,homeid,awayid,hdp1,hdp2,odds,betteam,statusID,status,livehomescore,liveawayscore
		,liveindicator,leagueid,sporttype,isNeutral,matchid,matchcode,betstatus,betcheck
		,(stake * @actualrate) AS stake,transdate,@transdesc transdesc
		,IsBlacklistLeague
	FROM @bettransm
	ORDER BY transid ASC
END
GO