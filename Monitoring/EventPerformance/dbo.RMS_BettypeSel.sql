/*<info serverAlias="DBRMS-bodb_RMS" executers="wsv_rms" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[RMS_BettypeSel] 
	@SportType SMALLINT = 43
											
AS

/*
Created: Danny
Date: 2022-03-01
DB: DBRMS/bodb_RMS
		
Revisions:

	- 20220301@Danny: Get data bettype by Sport [RedmineID: #169072]
	- 20230130@Danny: Monitor detail Performance for Event/Bettype/BetChoice Soccer [RedmineID: #182724]
	- 20240312@Cherry: Change SQL account in metadata (#202012)
	- 20241106@Cherry: Exclude Single Match Parlay (#209293)
	- 20241121@Cherry: Add sport Tennis and Badminton (#208397)

Parameter's Explanation:
	 EXEC dbo.RMS_BettypeSel 1
*/
BEGIN
SET NOCOUNT ON;

	;WITH t AS
	(
		SELECT	DISTINCT bettype, 
				bt.typenamee, 
				CASE WHEN SportType = 43 THEN CASE WHEN bettype IN (1,2,3,7,8,12,20,21) THEN 1 ELSE 2 END
					WHEN SportType = 2 THEN CASE WHEN bettype IN (1,2,3,7,8,12,20,21,609,610,611,612) THEN 1 ELSE 2 END
					WHEN SportType = 1 THEN CASE WHEN bettype IN (1,2,3,7,8,12,5,15) THEN 1 ELSE 2 END
					WHEN SportType = 5 THEN CASE WHEN bettype IN (1,3,20,153,154,155,156) THEN 1 END
					WHEN SportType = 9 THEN CASE WHEN bettype IN (20,701,704,705,706,707,708,709,710) THEN 1 
												WHEN bettype IN (702,703,711,712,713,714) THEN 2 END
					END AS GroupID  -- 1 Major, 2 Minor
		FROM bodb02.dbo.SportBettypeMatrix m WITH(NOLOCK)
			INNER JOIN bodb02.dbo.bettype bt WITH(NOLOCK) ON m.BetType = bt.typeid
		WHERE SportType = @SportType
			AND bt.typeid <> 38
	), result_ AS
	(
		SELECT	bettype, typenamee, GroupID, ROW_NUMBER() OVER(PARTITION BY GroupID ORDER BY typenamee ASC) AS rn
		FROM	t
		WHERE GroupID IN (1,2)
	)
	SELECT	bettype, typenamee, GroupID
	FROM	result_
	ORDER BY GroupID, CASE WHEN GroupID = 1 THEN bettype ELSE rn END


END

