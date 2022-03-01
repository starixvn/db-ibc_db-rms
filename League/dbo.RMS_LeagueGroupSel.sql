/*<info serverAlias="DBRMS-bodb_RMS" executers="bodbRMSNet" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[RMS_LeagueGroupSel] 
	@SportType SMALLINT = 1
											
AS

/*
Created: Danny
Date: 2022-03-01
DB: DBRMS/bodb_RMS
		
Revisions:

- 20220301@Danny: Get data leagueGroup by Sport [RedmineID: #169072]

Parameter's Explanation:
*/
BEGIN
SET NOCOUNT ON;

	IF @SportType = 1 
	BEGIN
		; WITH t AS
		(
			SELECT -1 AS LeagueGroupID, 'None' AS LeagueGroupName, 0 AS orderID
			UNION ALL
			SELECT GroupID AS LeageGroupID, GroupName AS LeagueGroupName, OrderID  
			FROM 	 dbo.rmLeagueGroup 
		)
		SELECT LeagueGroupID, LeagueGroupName
		FROM t
		ORDER BY orderID
	END


	IF @SportType = 2 
	BEGIN
		SELECT DISTINCT lg.GroupID AS LeagueGroupID, lg.GroupName AS LeagueGroupName
		FROM bodb02.dbo.League l WITH(NOLOCK)
		INNER JOIN bodb02.dbo.LeagueGroup lg WITH(NOLOCK) ON l.LeagueGroupID = lg.GroupID
		WHERE l.sporttype = 2
		ORDER BY lg.GroupName
	END

END
GO