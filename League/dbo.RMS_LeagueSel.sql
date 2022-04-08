
/*<info serverAlias="DBRMS-bodb_RMS" executers="bodbRMSNet" viewers="" isFunction="0" isNested="0"></info>*/

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

Parameter's Explanation:
*/
BEGIN
  SET NOCOUNT ON;

	IF @SportType = 1 
	BEGIN
		 SELECT l.leagueid, 
				l.leaguename, 
				mc.GroupId, 
				g.GroupName
		 FROM rmLeague mc WITH(NOLOCK)
			  INNER JOIN rmLeagueGroup g WITH(NOLOCK) ON mc.GroupId = g.GroupId
			  INNER JOIN bodb02.dbo.League l WITH(NOLOCK) ON mc.LeagueId = l.leagueid
		 WHERE (LEN(@LeagueName) = 0  OR l.leaguename LIKE '%' + @LeagueName + '%')
			   AND (@GroupId = 0  OR mc.GroupId = @GroupId)
		 ORDER BY g.OrderId, 
				  l.leaguename;
	END
	IF @SportType = 2 
	BEGIN
		 SELECT DISTINCT l.leagueid, 
				l.leaguename, 
				lg.GroupId, 
				lg.GroupName
		 FROM bodb_RMS.dbo.rmSumByLeague rm WITH(NOLOCK) 
		 INNER JOIN	bodb02.dbo.league l WITH(NOLOCK) ON rm.leagueId = l.leagueid
		 INNER JOIN bodb02.dbo.LeagueGroup lg WITH(NOLOCK) ON lg.GroupID = l.LeagueGroupID
		 WHERE   rm.winlostdate BETWEEN @FromDate AND @ToDate AND  l.sporttype = 2 
				AND (LEN(@LeagueName) = 0 OR l.leaguename LIKE '%' + @LeagueName + '%')
			    AND (@GroupId = 0 OR lg.GroupId = @GroupId)
		 ORDER BY l.leaguename;
	END

END
GO