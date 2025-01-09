/*<info serverAlias="DBRMS-bodb_RMS" executers="wsv_rms" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[RMS_ManageAlert_Alert]
	@FromDate DATE,
	@ToDate DATE,
	@AlertType VARCHAR(50) = '-1',
	@Member NVARCHAR(50) = '',
	@CheckBy NVARCHAR(50) = '',
	@IsNoChecked BIT = 1,
	@ActionType VARCHAR(50) = '-1',
	@TicketStatus VARCHAR(50) = '-1',
	@SportType VARCHAR(100) = '',
	@Selection VARCHAR(MAX) = '0',
	@Odds SMALLMONEY = NULL,
	@PageSize 	 INT = 0,
	@PageIndex   INT = 0

AS
/*
	Created by: 20230620@Cherry.Dang
	Task : Manage Alert Letstalk on PRMS
	DB: DBRMS/bodb_RMS
	
	Revisions:		
		20230620@Cherry: Initial (#189147)
		20230830@Cherry: Enhance (#192682)
		20240312@Cherry: Change SQL account in metadata (#202012)
		20240625@Cherry: Enhancement (#207024)
		20241212@Cherry: Separate Cricket (#214664)

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

		@SportType:
					= '1': soccer only
					= '-1': Combined other sports
					= '-2': Other sports
					= '-3': Combined sports
					= '-4': Saba soccer
					= '-5': Saba basketball

		@Selection:
					= '2,3': 2,3 selections
					= '10': 10 UP
					= '0' : All
*/

BEGIN
	SET NOCOUNT ON

	CREATE TABLE #tmpSport (SportType BIGINT)
	INSERT INTO #tmpSport (SportType)
	SELECT value FROM STRING_SPLIT(@SportType, ',')

	IF ',' + @SportType + ',' LIKE '%,-2,%'
		INSERT INTO #tmpSport (SportType)
		SELECT SportType FROM bodb02.dbo.Sports WITH (NOLOCK)
		WHERE SportType NOT IN (1,2,3,4,5,6,7,8,9,11,43,44,50)
			AND SportType <= 99

	CREATE TABLE #tmpSelection (Selection INT)

	IF ',' + @Selection + ',' LIKE '%,0,%'
	BEGIN
		SELECT @Selection = '2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,64,65,66,67,68,69,70,71,72,73,74,75,76,77,78,79,80,81,82,83,84,85,86,87,88,89,90,91,92,93,94,95,96,97,98,99,100'
		
		INSERT INTO #tmpSelection (selection)
		SELECT value FROM STRING_SPLIT(@Selection, ',')
	END
	ELSE IF ',' + @Selection + ',' LIKE '%,10,%'
	BEGIN
		SELECT @Selection = @Selection + ',11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,64,65,66,67,68,69,70,71,72,73,74,75,76,77,78,79,80,81,82,83,84,85,86,87,88,89,90,91,92,93,94,95,96,97,98,99,100'
		
		INSERT INTO #tmpSelection (Selection)
		SELECT value FROM STRING_SPLIT(@Selection, ',')
	END
	ELSE
	BEGIN
		INSERT INTO #tmpSelection (Selection)
		SELECT value FROM STRING_SPLIT(@Selection, ',')
	END

	CREATE TABLE #tmpAlertType (AlertTypeID SMALLINT)
	CREATE TABLE #tmpAlertAction (AlertActionID SMALLINT)
	CREATE TABLE #tmpStatusID(StatusID TINYINT)
	CREATE TABLE #tmpListTransID (TransID BIGINT)
	CREATE TABLE #tmprmAlertDetail (AlertID BIGINT, RefValInt BIGINT, RefType SMALLINT, AlertType SMALLINT)

	CREATE TABLE #tmprmBettrans
	(
		transid BIGINT,
		refno BIGINT,
		bettype INT,
		statusID TINYINT,
		hdp2 SMALLMONEY,		
		transid2 BIGINT
	)	

	CREATE TABLE #tmprmBettrans_Old
	(
		transid BIGINT,
		refno BIGINT,
		bettype INT,
		statusID TINYINT,
		hdp2 SMALLMONEY,		
		transid2 BIGINT
	)	

	CREATE TABLE #tmpAlert
	(
		AlertID BIGINT,
		AlertTime DATETIME,
		TransID BIGINT,
		CustID INT,
		RefNo BIGINT,
		BetType SMALLINT,
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
		RefNo BIGINT,
		BetType SMALLINT,
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

	CREATE UNIQUE CLUSTERED INDEX CX_selection ON #tmpSelection(selection)
    CREATE UNIQUE CLUSTERED INDEX CX_sporttype ON #tmpSport(sporttype)
    CREATE UNIQUE CLUSTERED INDEX CX_StatusID ON #tmpStatusID(StatusID)

	DECLARE @IsTest BIT = 0

	IF	OBJECT_NAME(@@PROCID) LIKE '%_xtest%'
		OR OBJECT_NAME(@@PROCID) LIKE '%_xpre%'
		OR OBJECT_NAME(@@PROCID) LIKE '%_UAT%'
		SELECT @IsTest = 1

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
			OR @IsNoChecked = 0
			)

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

	DECLARE @fAlertID BIGINT,@tAlertID BIGINT

	SELECT @fAlertID = MIN(AlertID),@tAlertID = MAX(AlertID)
	FROM #tmpAlert

	INSERT INTO #tmprmAlertDetail (AlertID, RefValInt, RefType, AlertType)
    SELECT d.AlertID, d.RefValInt, d.RefType, a.AlertType
    FROM dbo.rmAlertDetail d WITH(NOLOCK)
      INNER JOIN #tmpAlert a WITH(NOLOCK) ON d.AlertID = a.AlertID

    INSERT INTO #tmpListTransID (TransID)
    SELECT DISTINCT d.RefValInt TransID
    FROM #tmprmAlertDetail d WITH(NOLOCK)

	CREATE UNIQUE CLUSTERED INDEX CX_TransID ON #tmpListTransID(TransID)
	CREATE CLUSTERED INDEX CX_AlertID ON #tmprmAlertDetail(AlertID)
	
	INSERT INTO #tmprmBettrans
	(
		transid,
		refno,
		bettype,
		statusID, 
		hdp2,		
		transid2
	)
	SELECT b.transid,
		b.refno,
		b.bettype,
		b.statusID, 
		b.hdp2,		
		b.transid2
	FROM dbo.rmBettrans b WITH(NOLOCK)
	WHERE transid IN (SELECT TransID FROM #tmpListTransID)

	CREATE UNIQUE CLUSTERED INDEX CX_TransID ON #tmprmBettrans(transid)

	INSERT INTO #tmpDetail
	(	
		AlertID,
		TransID,
		RefNo,
		BetType,
		StatusID
	)
	SELECT 
		d.AlertID,
		d.RefValInt,
		b.refno,
		b.bettype,
		b.statusID
	FROM #tmprmAlertDetail d WITH(NOLOCK)
		INNER JOIN #tmprmBettrans b WITH(NOLOCK) ON d.RefValInt = b.transid
	WHERE d.RefType = 1
		AND (d.AlertType <> 1
			OR @SportType = ''
			OR EXISTS(SELECT TOP 1 1 FROM #tmpSport sp WHERE b.transid2 = sp.sporttype)
			)
		AND (@TicketStatus = '-1'
			OR EXISTS(SELECT TOP 1 1 FROM #tmpStatusID t WHERE b.StatusID = t.StatusID))
		AND EXISTS(SELECT TOP 1 1 FROM #tmpSelection s WHERE b.hdp2 = s.selection)
		AND d.AlertID BETWEEN @fAlertID AND @tAlertID 
	OPTION(RECOMPILE)

	DELETE FROM #tmpListTransID
    WHERE TransID IN (SELECT transid FROM #tmprmBettrans)	

	INSERT INTO #tmprmBettrans_OLD
    (
        transid,
        refno,
        bettype,
        statusID, 
        hdp2,       
        transid2
    )
    SELECT b.transid,
        b.refno,
        b.bettype,
        b.statusID, 
        b.hdp2,     
        b.transid2
    FROM dbo.rmBettrans_Old b WITH(NOLOCK)
    WHERE transid IN (SELECT TransID FROM #tmpListTransID)

	CREATE UNIQUE CLUSTERED INDEX CX_TransID ON #tmprmBettrans_OLD(transid)

	INSERT INTO #tmpDetail
	(	
		AlertID,
		TransID,
		RefNo,
		BetType,
		StatusID
	)
	SELECT 
		d.AlertID,
		d.RefValInt,
		b.refno,
		b.bettype,
		b.statusID
	FROM #tmprmAlertDetail d WITH(NOLOCK)
		INNER JOIN #tmprmBettrans_OLD b WITH(NOLOCK) ON d.RefValInt = b.transid
	WHERE d.RefType = 1
		AND (d.AlertType <> 1
			OR @SportType = ''
			OR EXISTS(SELECT TOP 1 1 FROM #tmpSport sp WHERE b.transid2 = sp.sporttype)
			)
		AND (@TicketStatus = '-1'
			OR EXISTS(SELECT TOP 1 1 FROM #tmpStatusID t WHERE b.StatusID = t.StatusID))
		AND EXISTS(SELECT TOP 1 1 FROM #tmpSelection s WHERE b.hdp2 = s.selection)
        AND d.AlertID BETWEEN @fAlertID AND @tAlertID 
	OPTION(RECOMPILE)
	
	DELETE a
	FROM #tmpAlert a			
	WHERE a.AlertID NOT IN (SELECT AlertID FROM #tmpDetail)

	UPDATE a
	SET a.IsSettled = 1
	FROM #tmpAlert a		
		LEFT JOIN #tmpDetail d ON a.AlertID = d.AlertID AND d.StatusID = 0
	WHERE d.AlertID IS NULL

	UPDATE a
	SET a.RefNo = d.RefNo,
		a.BetType = d.BetType
	FROM #tmpAlert a
		INNER JOIN #tmpDetail d ON a.AlertID = d.AlertID AND a.TransID = d.TransID
	
	;WITH CTE_Result AS(
	SELECT 
		d.AlertID AlertId,
		d.AlertTime,
		CASE WHEN d.AlertType = 3 THEN NULL ELSE d.TransID END BetId,
		d.RefNo,
		d.CustID CustId,
		d.BetType,
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
			WHEN a.ActionID = 4 THEN 'Choose Action' 
			ELSE a.ActionName END 'Action',
		ROW_NUMBER() OVER (ORDER BY d.AlertTime DESC) RN
	FROM #tmpAlert d
		INNER JOIN dbo.rmAlertType t WITH(NOLOCK) ON d.AlertType = t.AlertTypeID
		INNER JOIN dbo.rmAlertAction a WITH(NOLOCK) ON d.AlertAction = a.ActionID
		LEFT JOIN bodb02.dbo.customer c WITH(NOLOCK) ON d.CustID = c.custid
		LEFT JOIN bodb02.dbo.customer u WITH(NOLOCK) ON d.CheckBy = u.custid
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
	WHERE (i.od <= @Odds OR @Odds IS NULL)
	)
	SELECT AlertId,
		AlertTime,
		BetId,
		RefNo,
		CustId,
		BetType,
		AlertType,
		SportType,
		UserName,
		SimilarTickets,
		Selection,
		Odds,
		TotalBets,
		MemberStake,
		PotentialWinning,
		CompanyLose,
		CheckedBy,
		Action,
		RN
	INTO #Result
	FROM CTE_Result

	SELECT AlertId,
		AlertTime,
		BetId,
		RefNo,
		CustId,
		BetType,
		AlertType,
		SportType,
		UserName,
		SimilarTickets,
		Selection,
		Odds,
		TotalBets,
		MemberStake,
		PotentialWinning,
		CompanyLose,
		CheckedBy,
		Action 
	FROM #Result
	WHERE (RN >= (@PageIndex - 1) * @PageSize + 1 AND RN < @PageIndex * @PageSize + 1) 
		OR (@PageIndex = 0)
	ORDER BY AlertTime DESC

	SELECT COUNT(*) TotalRows
	FROM #Result

	DROP TABLE #tmpAlert
	DROP TABLE #tmpAlertAction
	DROP TABLE #tmpAlertType
	DROP TABLE #tmpDetail
	DROP TABLE #tmpStatusID
	DROP TABLE #Result
	DROP TABLE #tmpSelection
	DROP TABLE #tmpSport
	DROP TABLE #tmpListTransID
	DROP TABLE #tmprmBettrans
	DROP TABLE #tmprmBettrans_Old
	DROP TABLE #tmprmAlertDetail

END 
 

