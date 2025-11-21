/*<info serverAlias="DBRMS-bodb_RMS" executers="wsv_rms" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[RMS_Rpt_Parlay_TopWinners_Bet_Details]
	@transid	BIGINT
	,@refno		BIGINT
AS

/*
	Created: 20130813@Johnson
	DB: DBRMS-bodb_RMS
	Task: View bet details

	Revisions:
		- 20160926@Winnie: fix issue conflict refno with racing RedmineID: #64286
		- 20181224@Jacob: Esport 2, Add transdesc for bet list : #103001
		- 20191026@Jacob: Winloss by master RedmineID: [#122137]
		- 20200306@Percy: Fix issue missing data on bettransm/bettransm14/bettransmbk [RedmineID: #129935]
		- 20200510@Percy: Add Black League [RedmineID: #133961]
		- 20200821@Percy: Fix issue duplicate data due to MBBU process [RedmineID: #140078]
		- 20210319@Danny: Incorporate Cricket AIO into PRMS [RedmineID: #151319]
		- 20240312@Cherry: Change SQL account in metadata (#202012)
		- 20251020@Cherry: Integrate Hybrid Parlay (#242165)
*/

BEGIN
	SET NOCOUNT ON

	CREATE TABLE #MBU (BalanceUpDay SMALLDATETIME, MoveBetsDay SMALLDATETIME)
	INSERT INTO #MBU (BalanceUpDay, MoveBetsDay)
	EXEC bodb02.dbo.Age_SelBalanceUpDay

	DECLARE @BalanceUpDay SMALLDATETIME, @MoveBetsDay SMALLDATETIME
	SELECT  @BalanceUpDay = BalanceUpDay, @MoveBetsDay = MoveBetsDay FROM #MBU

	CREATE TABLE #BetListMP 
    (
		transid			BIGINT
		,bettype		INT
		,homeid			INT
		,awayid			INT
		,hdp1			SMALLMONEY
		,hdp2			SMALLMONEY
		,odds			SMALLMONEY
		,betteam		NVARCHAR(20)
		,statusid		INT
		,[status]		NVARCHAR(20)
		,livehomescore	SMALLINT
		,liveawayscore	SMALLINT
		,liveindicator	BIT
		,leagueid		INT
		,sporttype		SMALLINT
		,isNeutral		BIT
		,matchid		INT
		,matchcode		NVARCHAR(50)
		,betstatus		NVARCHAR(50)
		,betcheck		NVARCHAR(50)
		,stake			MONEY
    )

	-- Blacklist league
	DECLARE @BlacklistLeagueGroupId INT
	SELECT  @BlacklistLeagueGroupId = GroupId FROM dbo.rmLeagueGroup WITH (NOLOCK) WHERE GroupName = 'Blacklist'
	
	DECLARE @tpositiontaking SMALLMONEY, @actualrate FLOAT, @SQL NVARCHAR(MAX), @transdesc NVARCHAR(1000)
	
	SELECT  @tpositiontaking = tpositiontaking, @actualrate = actualrate, @transdesc = transdesc
	FROM bodb02.dbo.bettrans WITH (NOLOCK)
	WHERE transid = @transid

	IF @@ROWCOUNT = 0
		SELECT @tpositiontaking = tpositiontaking, @actualrate = actualrate, @transdesc = transdesc
		FROM bodb02.dbo.bettrans14 WITH (NOLOCK)
		WHERE transid = @transid

	IF @@ROWCOUNT = 0
		SELECT @tpositiontaking = tpositiontaking, @actualrate = actualrate, @transdesc = transdesc
		FROM DBARC.bodb_Archive.dbo.bettrans_bk WITH (NOLOCK)
		WHERE transid = @transid

	IF EXISTS (SELECT 1 FROM bodb02.dbo.bettransm WITH (NOLOCK) WHERE refno = @refno AND (statusID IN (0, 1) OR winlostdate > @MoveBetsDay))
		INSERT INTO #BetListMP
		(
			transid			
			,bettype		
			,homeid			
			,awayid			
			,hdp1			
			,hdp2			
			,odds			
			,betteam		
			,statusid		
			,[status]		
			,livehomescore	
			,liveawayscore	
			,liveindicator	
			,leagueid		
			,sporttype		
			,isNeutral		
			,matchid		
			,matchcode		
			,betstatus		
			,betcheck		
			,stake			
    )
        SELECT
			bm.transid,bm.bettype,m.homeid,m.awayid,bm.hdp1,bm.hdp2,bm.odds,bm.betteam,bm.statusid
			,bm.[status],bm.livehomescore,bm.liveawayscore,bm.liveindicator,m.leagueid,m.sporttype
			,m.isNeutral,CASE WHEN m.ChildMatchType = 200 THEN m.ParentID else m.matchid END,m.matchcode,m.betstatus,bm.betcheck,bm.stake
		FROM bodb02.dbo.bettransm bm WITH (NOLOCK)
			INNER JOIN bodb02.dbo.match m WITH (NOLOCK) ON bm.matchid = m.matchid
		WHERE bm.refno = @refno

	IF EXISTS (SELECT 1 FROM bodb02.dbo.bettransm14 WITH (NOLOCK) WHERE refno = @refno AND winlostdate BETWEEN @BalanceUpDay AND @MoveBetsDay)
		INSERT INTO #BetListMP
		(
			transid			
			,bettype		
			,homeid			
			,awayid			
			,hdp1			
			,hdp2			
			,odds			
			,betteam		
			,statusid		
			,[status]		
			,livehomescore	
			,liveawayscore	
			,liveindicator	
			,leagueid		
			,sporttype		
			,isNeutral		
			,matchid		
			,matchcode		
			,betstatus		
			,betcheck		
			,stake			
    )
        SELECT
			bm.transid,bm.bettype,m.homeid,m.awayid,bm.hdp1,bm.hdp2,bm.odds,bm.betteam,bm.statusid
			,bm.[status],bm.livehomescore,bm.liveawayscore,bm.liveindicator,m.leagueid,m.sporttype
			,m.isNeutral,CASE WHEN m.ChildMatchType = 200 THEN m.ParentID else m.matchid END,m.matchcode,m.betstatus,bm.betcheck,bm.stake
		FROM bodb02.dbo.bettransm14 bm WITH (NOLOCK)
			INNER JOIN bodb02.dbo.match14 m WITH (NOLOCK) ON bm.matchid = m.matchid
		WHERE bm.refno = @refno

	IF EXISTS (SELECT 1 FROM DBARC.bodb_Archive.dbo.bettransm WITH (NOLOCK) WHERE refno = @refno AND winlostdate < @BalanceUpDay)
	BEGIN
		SELECT @SQL = 'SELECT transid,bettype,homeid,awayid,hdp1,hdp2,odds,betteam,statusid
							,[status],livehomescore,liveawayscore,liveindicator,leagueid,sporttype
							,isNeutral,matchid,matchcode,betstatus,betcheck,transdesc,stake
						FROM OPENQUERY(DBARC, ''SELECT bm.transid,bm.bettype,m.homeid,m.awayid,bm.hdp1,bm.hdp2,bm.odds,bm.betteam,bm.statusid
														,bm.[status],bm.livehomescore,bm.liveawayscore,bm.liveindicator,m.leagueid,m.sporttype
														,m.isNeutral,CASE WHEN m.ChildMatchType = 200 THEN m.ParentID else m.matchid END matchid,m.matchcode,m.betstatus,bm.betcheck,bm.stake
												FROM bodb_Archive.dbo.bettransm bm WITH (NOLOCK)
													INNER JOIN bodb_Archive.dbo.match_bk m WITH (NOLOCK) ON bm.matchid = m.matchid
												WHERE bm.refno = ' + CONVERT(VARCHAR(50), @refno) + ''')'

		
		INSERT INTO #BetListMP
		(
			transid			
			,bettype		
			,homeid			
			,awayid			
			,hdp1			
			,hdp2			
			,odds			
			,betteam		
			,statusid		
			,[status]		
			,livehomescore	
			,liveawayscore	
			,liveindicator	
			,leagueid		
			,sporttype		
			,isNeutral		
			,matchid		
			,matchcode		
			,betstatus		
			,betcheck		
			,stake			
		)
        EXECUTE sp_executesql @SQL
	END

	-- Return data
	SELECT
		transid,bettype,homeid,awayid,hdp1,hdp2,odds,betteam,statusid,STATUS
		,livehomescore,liveawayscore,liveindicator,b.leagueid,sporttype,isNeutral
		,matchid,matchcode,betstatus,betcheck,@transdesc transdesc
		,(stake * (1 - @tpositiontaking) * @actualrate) AS stake
		,CASE WHEN l.LeagueId IS NOT NULL THEN 1 ELSE 0 END AS IsBlacklistLeague
     FROM #BetListMP b
		LEFT JOIN dbo.rmLeague l WITH (NOLOCK) ON b.leagueid = l.LeagueId AND l.GroupId = @BlacklistLeagueGroupId
     ORDER BY TransID DESC

	 DROP TABLE #BetListMP
	 DROP TABLE #MBU
END
GO