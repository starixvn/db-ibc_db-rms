/*<info serverAlias="DBRMS-bodb_RMS" executers="bodbRMSNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[RMS_BetList_BetBuilder_MatchDetail]
	@transid BIGINT
AS

/*  
	Created: 20190220@Jacob
	DB: DBRMS-bodb_RMS
	Task: Get match detail from BetBuilder ticket (Single Match Parlay)
	
	Revisions:
		- 20190220@Jacob: Add Bet Builder [RedmineID: #108694]
		- 20200510@Percy: Add Blacklist league [RedmineID: #133961]
*/

BEGIN
	SET NOCOUNT ON

	-- Blacklist league
	DECLARE @BlacklistLeagueGroupId INT, @IsBlacklistLeague BIT = 0
	SELECT  @BlacklistLeagueGroupId = GroupId FROM dbo.rmLeagueGroup WITH (NOLOCK) WHERE GroupName = 'Blacklist'

	DECLARE @matchid INT, @leagueid INT, @range TINYINT -- 1: bettrans, 2: bettrans14, 3: bettrans_bk
	
	SELECT @matchid = matchid, @range = 1 FROM dbo.rmBettrans WITH (NOLOCK) WHERE transid = @transid
	SELECT @leagueid = leagueid FROM bodb02.dbo.match WITH (NOLOCK) WHERE matchid = @matchid

	IF @matchid IS NULL
	BEGIN
		SELECT @matchid = matchid, @range = 2 FROM bodb02.dbo.bettrans14 WITH (NOLOCK) WHERE transid = @transid
		SELECT @leagueid = leagueid FROM bodb02.dbo.match14 WITH (NOLOCK) WHERE matchid = @matchid
	END

	IF @matchid IS NULL
	BEGIN
		SELECT @matchid = matchid, @range = 3 FROM DBARC.bodb_Archive.dbo.bettrans_bk WITH (NOLOCK) WHERE transid = @transid
		SELECT @leagueid = leagueid FROM DBARC.bodb_Archive.dbo.match_bk WITH (NOLOCK) WHERE matchid = @matchid
	END

	IF EXISTS (SELECT 1 FROM dbo.rmLeague WITH (NOLOCK) WHERE leagueid = @leagueid AND GroupId = @BlacklistLeagueGroupId)
		SELECT @IsBlacklistLeague = 1

	IF @range = 1
		SELECT homeid, awayid, sporttype, leagueid, GlobalShowTime AS EventDate, 38 AS bettype, @IsBlacklistLeague AS IsBlacklistLeague
		FROM bodb02.dbo.match WITH (NOLOCK)
		WHERE matchid = @matchid
	ELSE IF @range = 2
		SELECT homeid, awayid, sporttype, leagueid, GlobalShowTime AS EventDate, 38 AS bettype, @IsBlacklistLeague AS IsBlacklistLeague
		FROM bodb02.dbo.match14 WITH (NOLOCK)
		WHERE matchid = @matchid
	ELSE IF @range = 3
		SELECT homeid, awayid, sporttype, leagueid, GlobalShowTime AS EventDate, 38 AS bettype, @IsBlacklistLeague AS IsBlacklistLeague
		FROM DBARC.bodb_Archive.dbo.match_bk WITH (NOLOCK)
		WHERE matchid = @matchid
END
GO