/*<info serverAlias="DBRMS-bodb_RMS" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[RMS_ManageAlert_Alert]
	@FromDate DATE,
	@ToDate DATE,
	@AlertType VARCHAR(50) = '-1',
	@Member NVARCHAR(50) = '',
	@CheckBy NVARCHAR(50) = '',
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
		TransInfo VARBINARY(MAX),
		IsSettled BIT DEFAULT(0)
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

	IF @Member <> ''
	BEGIN
		DELETE a
		FROM #tmpAlert a
			LEFT JOIN bodb02.dbo.customer c WITH(NOLOCK) ON a.CustID = c.custid AND c.username = @Member
		WHERE c.CustID IS NULL
	END

	IF @CheckBy <> ''
	BEGIN
		DELETE a
		FROM #tmpAlert a
			LEFT JOIN bodb02.dbo.customer c WITH(NOLOCK) ON a.CheckBy = c.custid AND c.username = @CheckBy
		WHERE c.CustID IS NULL
	END

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

	IF @TicketStatus <> '-1'
	BEGIN		
		DELETE a
		FROM #tmpAlert a			
		WHERE NOT EXISTS(SELECT TOP 1 1
						FROM #tmpDetail d
						WHERE d.AlertID = a.AlertID
							AND d.StatusID IN (SELECT StatusID FROM #tmpStatusID))
	END

	UPDATE a
	SET a.IsSettled = 1
	FROM #tmpAlert a			
	WHERE NOT EXISTS(SELECT TOP 1 1
					FROM #tmpDetail d
					WHERE d.AlertID = a.AlertID
						AND d.StatusID = 0)
	
	SELECT 
		d.AlertID AlertId,
		d.AlertTime,
		d.TransID BetId,
		t.AlertTypeName AlertType,
		i.sp SportType,
		c.username UserName,
		i.si SimilarTickets,
		i.sl Selection,
		i.od Odds,
		i.tb TotalBets,
		i.ms MemberStake,
		i.pw PotentialWinning,
		i.pl CompanyLose,
		u.username CheckedBy,
		CASE WHEN a.ActionID = 0 AND d.IsSettled = 1 THEN 'No Action' 
			WHEN a.ActionID = 0 AND d.IsSettled = 0 THEN 'Choose Action' 
			ELSE a.ActionName END 'Action'
	FROM #tmpAlert d
		INNER JOIN dbo.rmAlertType t WITH(NOLOCK) ON d.AlertType = t.AlertTypeID
		INNER JOIN dbo.rmAlertAction a WITH(NOLOCK) ON d.AlertAction = a.ActionID
		INNER JOIN bodb02.dbo.customer c WITH(NOLOCK) ON d.CustID = c.custid
		LEFT JOIN bodb02.dbo.customer u WITH(NOLOCK) ON d.CustID = u.custid AND d.CheckBy IS NOT NULL
		CROSS APPLY OPENJSON(CAST(DECOMPRESS(d.TransInfo) AS NVARCHAR(MAX)))
			WITH(
				sp VARCHAR(50),
				si INT,
				sl VARCHAR(50),
				od MONEY,
				tb INT,
				ms MONEY,
				pw MONEY,
				pl MONEY
				) AS i

	DROP TABLE #tmpAlert
	DROP TABLE #tmpAlertAction
	DROP TABLE #tmpAlertType
	DROP TABLE #tmpDetail
	DROP TABLE #tmpStatusID

END 
 

