/*<info serverAlias="DBRMS-bodb_RMS" executers="wsv_rms" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[RMS_ComboParlay_PotentialWinning_UserTracking]
	@userid			INT,
	@username		NVARCHAR(50),
	@transid		VARCHAR(MAX),
	@statusID		SMALLINT OUTPUT,
	@message		VARCHAR(4000) = '' OUTPUT

AS

/*
	Created: 20210701@Danny
	DB: DBRMS-bodb_RMS
	Task: ComboParlay PotentialWinning User Tracking

	Revisions:
		- 20210701@Danny: Track User Monitoring [RedmineID: #153875]
		- 20211007@Danny: Track User Monitoring on ComboParlay_Betlist Report [RedmineID: #162872]
		- 20240312@Cherry: Change SQL account in metadata (#202012)
		- 20241120@Cherry: Add user tracking in Similar Bets (#212544)

	Parameter's Explanation:
*/

BEGIN
	SET NOCOUNT ON

	BEGIN TRY
		DECLARE @logtime DATETIME = GETDATE()
	-- Handle transid list
		DECLARE @transidTab TABLE (transID BIGINT)
		INSERT INTO @transidTab (transID)
		SELECT CAST (val AS BIGINT) from f_RMS_strSplit(@transid, ',')

		-- Remove settle ticket by user
		BEGIN
			CREATE TABLE #del_trans (transid BIGINT)
			INSERT INTO #del_trans (transid)
			SELECT  t.transid 
			FROM dbo.rmUserTrackingLog t WITH(NOLOCK)
			LEFT JOIN dbo.rmBettrans rm WITH(NOLOCK) ON t.transid = rm.transid
			WHERE t.userid = @userid AND (rm.statusID <> 0 OR rm.transid IS NULL)


			DELETE t
			FROM dbo.rmUserTrackingLog t WITH(ROWLOCK, UPDLOCK)
			INNER JOIN #del_trans d ON t.transid = d.transid
			WHERE t.userid = @userid

			DROP TABLE #del_trans
		END

		-- Insert new tracking log
		BEGIN
			IF EXISTS (SELECT 1 FROM dbo.rmUserTrackingLog WITH(NOLOCK) WHERE transid IN (SELECT transid FROM @transidTab))
			BEGIN
				INSERT INTO dbo.rmUserTrackingLog (userid, username, transid, transdate)
				SELECT @userid, @username, t.transid, @logtime
				FROM @transidTab t
				LEFT JOIN dbo.rmUserTrackingLog r WITH(NOLOCK) ON t.transID = r.transid
				WHERE r.transid IS NULL

				SELECT @statusID = 1
				SELECT @message = @message + CAST(transid AS VARCHAR(20)) + ':' + username+ ','
				FROM dbo.rmUserTrackingLog r WITH(NOLOCK)
				WHERE transid IN (SELECT x.transid FROM @transidTab x)
			END
			ELSE
			BEGIN
				INSERT INTO dbo.rmUserTrackingLog (userid, username, transid, transdate)
				SELECT @userid, @username, transid, @logtime
				FROM @transidTab

				SELECT  @statusID = 0
				SELECT @message = @message + CAST(transid AS VARCHAR(20)) + ':' + username+ ','
				FROM dbo.rmUserTrackingLog r WITH(NOLOCK)
				WHERE transid IN (SELECT x.transid FROM @transidTab x)
			END

		END

	END TRY
	BEGIN CATCH
			SELECT  @statusID = 2, @message = ERROR_MESSAGE() 
		
	END CATCH

END
GO


