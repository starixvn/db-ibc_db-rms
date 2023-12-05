/*<info serverAlias="DBRMS-bodb_RMS" executers="bodbRMSNet" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[RMS_Rpt_Parlay_UsersStatisticsByIP]
	@fromdate		DATETIME
	,@TicketStatus	VARCHAR(50) = '-1'
	,@pageIndex		INT = 1
	,@pageSize		INT = 100
	,@totalItems	INT = 0 OUTPUT
	,@max_transid	BIGINT = 0 OUTPUT
AS

/*
	Created: 20140630@Johnson
	DB: DBRMS-bodb_RMS
	Task: IP statistics by users
	
	Revisions:
		- 20200510@Percy: Change condition of transdate [RedmineID: #133961]
		- 20231115@Cherry: Add param TicketStatus, output column (#196550)

	Param:
		- @TicketStatus: 
			-1:  All
			0:   Running
			112: Won
			113: Lose
			111: Draw
			101: Reject
			102: Void
*/

BEGIN
	SET NOCOUNT ON

	CREATE TABLE #tmpStatus (statusid INT)
	INSERT INTO #tmpStatus (statusid)
	SELECT value FROM STRING_SPLIT(@TicketStatus, ',')

	DECLARE @RowStart INT, @RowEnd INT
	SELECT  @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1
	
	IF @max_transid = 0
		SELECT @max_transid = MAX(transid) FROM rmBettrans WITH (NOLOCK)
	
	SELECT @totalItems = COUNT(1)
	FROM
	(
		SELECT IP
		FROM dbo.rmBettrans b WITH (NOLOCK)
		WHERE transdate >= @fromdate AND transdate < DATEADD(DAY, 1, @fromdate)
			AND (@TicketStatus = '-1' OR
				EXISTS (SELECT TOP 1 1 FROM #tmpStatus t WHERE b.statusID = t.statusid)
				)
		GROUP BY IP
		HAVING COUNT(DISTINCT custid) >= 2
	) r
	
	SELECT IP, cntUsers, Stake, WinningAmount, HouseLoseAmount
	FROM
	(
		SELECT IP, cntUsers, Stake, WinningAmount, HouseLoseAmount,
			ROW_NUMBER() OVER(ORDER BY cntUsers DESC) AS rn
		FROM
		(
			SELECT IP, 
				COUNT(DISTINCT custid) AS cntUsers,
				SUM(stake * actualrate) Stake,
				SUM(CASE WHEN statusid = 0 THEN (odds2 - 1) * stake * actualrate
						ELSE (winlost - actual_stake) * actualrate
					END) WinningAmount,
				SUM(CASE WHEN statusid = 0 THEN (odds2 - 1) * stake * actualrate * (1 - tpositiontaking)
					ELSE ((winlost - actual_stake) * (1 - tpositiontaking - CONVERT(DECIMAL(9, 8), ISNULL(epositiontaking, 0))) + scomm - CASE WHEN tpositiontaking = 1 THEN 0 ELSE scomm * CONVERT(DECIMAL(9, 8), ISNULL(epositiontaking, 0)) / (1 - tpositiontaking) END) * actualrate
					END) HouseLoseAmount
			FROM rmBettrans b WITH(NOLOCK)
			WHERE transdate >= @fromdate AND transdate < DATEADD(DAY, 1, @fromdate)
				AND (@TicketStatus = '-1' OR
					 EXISTS (SELECT TOP 1 1 FROM #tmpStatus t WHERE b.statusID = t.statusid)
					)
			GROUP BY IP
			HAVING COUNT(DISTINCT custid) >= 2
		) r
	) t
	WHERE rn BETWEEN @RowStart AND @RowEnd

	DROP TABLE #tmpStatus
END 
GO