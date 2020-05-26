/*<info serverAlias="DBRMS-bodb_RMS" executers="bodbRMSNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[RMS_BetList_PenaltyShootout_MatchDetail]
	@transid BIGINT
AS

/*  
	Created: 20200510@Percy
	DB: DBRMS-bodb_RMS
	Task: Penalty Shootout Combo - Get match detail
	
	Revisions:  
		- 20200510@Percy: Initialize SP [RedmineID: #133961]
*/

BEGIN
	SET NOCOUNT ON

	-- Blacklist league
	DECLARE @BlacklistLeagueGroupId INT, @IsBlacklistLeague BIT = 0
	SELECT  @BlacklistLeagueGroupId = GroupId FROM dbo.rmLeagueGroup WITH (NOLOCK) WHERE GroupName = 'Blacklist'

	DECLARE @matchid INT, @leagueid INT, @betteam NVARCHAR(10), @betcheck NVARCHAR(50), @range TINYINT -- 1: bettrans, 2: bettrans14, 3: bettrans_bk
	
	SELECT @matchid = matchid, @betteam = betteam, @betcheck = betcheck, @range = 1 FROM dbo.rmBettrans WITH (NOLOCK) WHERE transid = @transid
	SELECT @leagueid = leagueid FROM bodb02.dbo.match WITH (NOLOCK) WHERE matchid = @matchid

	IF @matchid IS NULL
	BEGIN
		SELECT @matchid = matchid, @betteam = betteam, @betcheck = betcheck, @range = 2 FROM bodb02.dbo.bettrans14 WITH (NOLOCK) WHERE transid = @transid
		SELECT @leagueid = leagueid FROM bodb02.dbo.match14 WITH (NOLOCK) WHERE matchid = @matchid
	END

	IF @matchid IS NULL
	BEGIN
		SELECT @matchid = matchid, @betteam = betteam, @betcheck = betcheck, @range = 3 FROM DBARC.bodb_Archive.dbo.bettrans_bk WITH (NOLOCK) WHERE transid = @transid
		SELECT @leagueid = leagueid FROM DBARC.bodb_Archive.dbo.match_bk WITH (NOLOCK) WHERE matchid = @matchid
	END

	IF EXISTS (SELECT 1 FROM dbo.rmLeague WITH (NOLOCK) WHERE leagueid = @leagueid AND GroupId = @BlacklistLeagueGroupId)
		SELECT @IsBlacklistLeague = 1

	IF @range = 1
		SELECT homeid, awayid, sporttype, leagueid, GlobalShowTime AS EventDate, 376 AS bettype, @transid AS transid, @betteam AS betteam, @betcheck AS betcheck, @IsBlacklistLeague AS IsBlacklistLeague
		FROM bodb02.dbo.match WITH (NOLOCK)
		WHERE matchid = @matchid
	ELSE IF @range = 2
		SELECT homeid, awayid, sporttype, leagueid, GlobalShowTime AS EventDate, 376 AS bettype, @transid AS transid, @betteam AS betteam, @betcheck AS betcheck, @IsBlacklistLeague AS IsBlacklistLeague
		FROM bodb02.dbo.match14 WITH (NOLOCK)
		WHERE matchid = @matchid
	ELSE IF @range = 3
		SELECT homeid, awayid, sporttype, leagueid, GlobalShowTime AS EventDate, 376 AS bettype, @transid AS transid, @betteam AS betteam, @betcheck AS betcheck, @IsBlacklistLeague AS IsBlacklistLeague
		FROM DBARC.bodb_Archive.dbo.match_bk WITH (NOLOCK)
		WHERE matchid = @matchid
END
GO