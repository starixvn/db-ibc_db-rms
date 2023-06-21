/*<info serverAlias="DBRMS-bodb_RMS" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[RMS_ManageAlert_Alert]
	@FromDate DATE,
	@ToDate DATE,
	@AlertType VARCHAR(50) = '-1',
	@Member NVARCHAR(50),
	@CheckBy NVARCHAR(50),
	@IsNoChecked BIT,
	@ActionType VARCHAR(50) = '-1',
	@TicketStatus VARCHAR(50) = '-1'

AS
/*
	Created by: 20230620@Cherry.Dang
	Task : Manage Alert Letstalk on PRMS
	DB: DBRMS/bodb_RMS
	
	Revisions:		
		20230620@Cherry: Initial (#189147)

	Param:
		@AlertType = 1: Similar Bet
				   = 2: Small Odds
				   = 3: Potential Winning
				   = 4: Last Pending Tickets
				   = 5: Small League & Odds
				   = -1: All

		@ActionType = 0: No Action
					= 1: Send S&V
					= 2: Send OS
					= 3: Take Note
					= -1: All

		@TicketStatus = 112: Won
					  = 113: Lose
					  = 0: Running
					  = -1: All
*/

BEGIN
	SET NOCOUNT ON

	CREATE TABLE #tmpAlertType (AlertTypeID SMALLINT)
	CREATE TABLE #tmpAlertAction (AlertActionID SMALLINT)
	CREATE TABLE #tmpStatusID(StatusID TINYINT)

	CREATE TABLE #tmpAlert
	(
		AlertID BIGINT,
		AlertTime DATETIME,
		TransID BIGINT,
		CustID INT,
		AlertType SMALLINT,
		CheckBy INT,
		AlertAction SMALLINT,
		TransInfo VARBINARY(MAX)
	)

	CREATE TABLE #tmpDetail
	(
		AlertID BIGINT,
		TransID BIGINT,
		StatusID TINYINT
	)

	IF @AlertType <> '-1' 
	BEGIN
		INSERT INTO #tmpAlertType (AlertTypeID)
		SELECT val
        FROM bodb02.dbo.strSplit(@AlertType, ',')
	END

	IF @ActionType <> '-1' 
	BEGIN
		INSERT INTO #tmpAlertAction (AlertActionID)
		SELECT val
        FROM bodb02.dbo.strSplit(@ActionType, ',')
	END

	IF @TicketStatus <> '-1' 
	BEGIN
		INSERT INTO #tmpStatusID (StatusID)
		SELECT val
        FROM bodb02.dbo.strSplit(@TicketStatus, ',')
	END

	DECLARE @IsTest BIT = 0
	SELECT @IsTest = bodb02.dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO #tmpAlert
	(
		AlertID,
		AlertTime,
		TransID,
		CustID,
		AlertType,
		CheckBy,
		AlertAction,
		TransInfo
	)
	SELECT AlertID,
		AlertTime,
		TransID,
		CustID,
		AlertType,
		CheckBy,
		AlertAction,
		TransInfo
	FROM dbo.rmAlert a WITH(NOLOCK)
	WHERE CAST(AlertTime AS DATE) BETWEEN @FromDate AND @ToDate
		AND IsTest = @IsTest
		AND (@AlertType = '-1' OR EXISTS(SELECT TOP 1 1 FROM #tmpAlertType t WHERE t.AlertTypeID = a.AlertType))
		AND (@ActionType = '-1' OR EXISTS(SELECT TOP 1 1 FROM #tmpAlertAction l WHERE l.AlertActionID = a.AlertAction))
		AND ((@IsNoChecked = 1 AND CheckBy IS NULL)
			OR (@IsNoChecked = 0 AND CheckBy IS NOT NULL))

	IF @TicketStatus <> '-1'
	BEGIN
		INSERT INTO #tmpDetail
		(	
			AlertID,
			TransID
		)
		SELECT
			AlertID,
			RefValInt
		FROM dbo.rmAlertDetail WITH(NOLOCK)
		WHERE AlertID IN (SELECT AlertID FROM #tmpAlert)
			AND RefType = 1

		UPDATE d
		SET d.StatusID = t.statusID
		FROM #tmpDetail d
			INNER JOIN (
				SELECT transid, statusID
				FROM dbo.rmBettrans b WITH(NOLOCK) 
				WHERE b.transid IN (SELECT TransID FROM #tmpDetail)
				UNION 
				SELECT transid, statusID
				FROM dbo.rmBettrans_Old b WITH(NOLOCK) 
				WHERE b.transid IN (SELECT TransID FROM #tmpDetail)
			) t ON d.TransID = t.transid

		DELETE a
		FROM #tmpAlert a			
		WHERE NOT EXISTS(SELECT TOP 1 1
						FROM #tmpDetail d
						WHERE d.AlertID = a.AlertID
							AND d.StatusID IN (SELECT StatusID FROM #tmpStatusID))
	END
	
	DECLARE @TransList VARCHAR(MAX), @TransID BIGINT, @CustID INT, @AlertID BIGINT
	CREATE TABLE #tmpTransID (TransID BIGINT)
	
	BEGIN TRY
		BEGIN TRANSACTION
			SELECT @TransList = tl
			FROM  OPENJSON (CAST( DECOMPRESS(@TransInfo) AS NVARCHAR(MAX)))
			WITH (
				tl VARCHAR(MAX)
				)

			INSERT INTO #tmpTransID (TransID)
			SELECT val
			FROM bodb02.dbo.strSplit(@TransList, ',')

			SELECT @TransID = MAX(TransID)
			FROM #tmpTransID

			SELECT @CustID = t.CustID
			FROM (
				SELECT custid 
				FROM dbo.rmBettrans WITH(NOLOCK)
				WHERE transid = @TransID
				UNION
				SELECT custid 
				FROM dbo.rmBettrans_Old WITH(NOLOCK)
				WHERE transid = @TransID
			) t		

			INSERT INTO dbo.rmAlert (AlertTime, TransID, CustID, AlertType, TransInfo, IsTest)
			SELECT @AlertTime, @TransID, @CustID, @AlertType, @TransInfo, @IsTest

			SELECT @AlertID = IDENT_CURRENT('rmAlert')

			INSERT INTO dbo.rmAlertDetail (AlertID, RefType, RefValInt)
			SELECT @AlertID, 1, TransID
			FROM #tmpTransID

		COMMIT TRANSACTION
	END TRY
	BEGIN CATCH
		SELECT @ErrorMsg = error_message()
		ROLLBACK TRANSACTION
	END CATCH

END 
 

