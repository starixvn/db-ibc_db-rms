
/*<info serverAlias="DBRMS-bodb_RMS" executers="wsv_rms" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[RMS_LeagueSel] @LeagueName	NVARCHAR(100)	= '', 
                                      @GroupId		INT				= 0,
									  @SportType	SMALLINT		= 1,
									  @FromDate		DATE			= NULL,
									  @ToDate		DATE			= NULL
AS

/*
Created: Jacob
Date: 2020-01-20
Task: League Management
DB: DBRMS/bodb_RMS
		
Revisions:

- 20200120@Jacob: League Management #127381
- 20220301@Danny: Get league info by Sport And League Group [RedmineID: #169072]
- 20240815@Cherry: Get None League Group (#204375)

Parameter's Explanation:
	@GroupId = 0: All Assigned League Group
			 = -1: None League Group
			 = -2: All Assigned & None League Group
*/
BEGIN
  SET NOCOUNT ON;

	CREATE TABLE #Result (
		OrderId SMALLINT,
		leagueid INT, 
		leaguename NVARCHAR(500), 
		GroupId INT, 
		GroupName VARCHAR(50)
	)

	IF @SportType = 1 
	BEGIN
		INSERT INTO #Result (
			OrderId,
			leagueid, 
			leaguename, 
			GroupId, 
			GroupName)
		 SELECT g.OrderId,
				l.leagueid, 
				l.leaguename, 
				mc.GroupId, 
				g.GroupName
		 FROM rmLeague mc WITH(NOLOCK)
			  INNER JOIN rmLeagueGroup g WITH(NOLOCK) ON mc.GroupId = g.GroupId
			  INNER JOIN bodb02.dbo.League l WITH(NOLOCK) ON mc.LeagueId = l.leagueid
		 WHERE (LEN(@LeagueName) = 0  OR l.leaguename LIKE '%' + @LeagueName + '%')
			   AND (@GroupId IN (0,-2)  OR mc.GroupId = @GroupId)

		INSERT INTO #Result (
			OrderId,
			leagueid, 
			leaguename, 
			GroupId, 
			GroupName)
		 SELECT DISTINCT 1 OrderId,
				l.leagueid, 
				l.leaguename, 
				-1 GroupId, 
				'None' GroupName
		 FROM bodb_RMS.dbo.rmSumByLeague rm WITH(NOLOCK) 
			INNER JOIN bodb02.dbo.league l WITH(NOLOCK) ON rm.leagueId = l.leagueid
			LEFT JOIN rmLeague mc WITH(NOLOCK) ON mc.leagueid=rm.leagueid
		 WHERE   rm.winlostdate BETWEEN @FromDate AND @ToDate 
				AND l.sporttype = 1
				AND (LEN(@LeagueName) = 0 OR l.leaguename LIKE '%' + @LeagueName + '%')
			    AND @GroupId IN (-1,-2)
				AND mc.leagueid IS NULL
	END
	IF @SportType = 2 
	BEGIN
		INSERT INTO #Result (
			OrderId,
			leagueid, 
			leaguename, 
			GroupId, 
			GroupName)
		 SELECT DISTINCT 1 OrderId,
				l.leagueid, 
				l.leaguename, 
				lg.GroupId, 
				lg.GroupName
		 FROM bodb_RMS.dbo.rmSumByLeague rm WITH(NOLOCK) 
			INNER JOIN	bodb02.dbo.league l WITH(NOLOCK) ON rm.leagueId = l.leagueid
			INNER JOIN bodb02.dbo.LeagueGroup lg WITH(NOLOCK) ON lg.GroupID = l.LeagueGroupID
		 WHERE   rm.winlostdate BETWEEN @FromDate AND @ToDate 
				AND l.sporttype = 2 
				AND (LEN(@LeagueName) = 0 OR l.leaguename LIKE '%' + @LeagueName + '%')
			    AND (@GroupId IN (0,-1,-2) OR lg.GroupId = @GroupId)
	END

	SELECT
			leagueid, 
			leaguename, 
			GroupId, 
			GroupName
	FROM #Result
	ORDER BY OrderId,
			leaguename

END
GO