
/*<info serverAlias="DBRMS-bodb_RMS" executers="bodbRMSNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[RMS_LeagueSel] @LeagueName NVARCHAR(100) = '', 
                                      @GroupId    INT           = 0
AS

/*
Created: Jacob
Date: 2020-01-20
Task: League Management
DB: DBRMS/bodb_RMS
		
Revisions:

- 20200120@Jacob: League Management #127381

Parameter's Explanation:
*/

     SET NOCOUNT ON;
     SELECT l.leagueid, 
            l.leaguename, 
            mc.GroupId, 
            g.GroupName
     FROM rmLeague mc WITH(NOLOCK)
          INNER JOIN rmLeagueGroup g WITH(NOLOCK) ON mc.GroupId = g.GroupId
          INNER JOIN bodb02.dbo.League l WITH(NOLOCK) ON mc.LeagueId = l.leagueid
     WHERE(LEN(@LeagueName) = 0
           OR l.leaguename LIKE '%' + @LeagueName + '%')
          AND (@GroupId = 0
               OR mc.GroupId = @GroupId)
     ORDER BY g.OrderId, 
              l.leaguename;
GO