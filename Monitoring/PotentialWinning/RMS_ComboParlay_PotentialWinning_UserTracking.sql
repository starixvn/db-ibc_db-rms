/*<info serverAlias="DBRMS-bodb_RMS" executers="bodbRMSNet" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[RMS_ComboParlay_PotentialWinning_UserTracking]
	@username		NVARCHAR(50),
	@transid		VARCHAR(MAX)

AS

/*
	Created: 20210701@Danny
	DB: DBRMS-bodb_RMS
	Task: ComboParlay PotentialWinning User Tracking

	Revisions:
		- 20210701@Danny: Track User Monitoring [RedmineID: #153875]


	Parameter's Explanation:
		- @selection:
					. '2,3': 2,3 selections
					. '10': 10 UP
					. '0' : All
		- @sporttype:
					. '1': soccer only
					. '-1': Combined other sports
					. '-2': Other sports
					. '-3': Combined sports
		- @level:
					. '0': none
					. '1,2,3': level 1,2,3
		- @ParlayType:
					. 1: Mix parlay
					. 2: Combo parlay
					. 3: Single Match Parlay
					. 4: Panalty shootout combo
					. 5: GOF
		
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @logtime DATETIME = GETDATE()

	-- Handle transid list
	DECLARE @transidTab TABLE (transID BIGINT)
	INSERT INTO @transidTab (transID)
	SELECT CAST (val AS BIGINT) from RMS_strSplit(@transid, ',')

	-- Remove settle ticket by user
	BEGIN
		CREATE TABLE #del_trans (transid BIGINT)
		INSERT INTO #del_trans (transid)
		SELECT  t.transid 
		FROM dbo.rmUserTrackingLog t WITH(NOLOCK)
		LEFT JOIN dbo.rmBettrans rm WITH(NOLOCK) ON t.transid = rm.transid
		WHERE t.username = @username AND (rm.statusID <> 0 OR rm.transid IS NULL)


		DELETE t
		FROM dbo.rmUserTrackingLog t WITH(ROWLOCK, UPDLOCK)
		INNER JOIN #del_trans d ON t.transid = d.transid
		WHERE t.username = @username

		DROP TABLE #del_trans
	END

	-- Insert new tracking log
	BEGIN
		INSERT INTO dbo.rmUserTrackingLog (username, transid, transdate)
		SELECT @username, transid, @logtime
		FROM @transidTab

	END

END
GO