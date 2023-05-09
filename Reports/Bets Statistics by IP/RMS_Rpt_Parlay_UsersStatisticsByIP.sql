
ALTER PROCEDURE [dbo].[RMS_Rpt_Parlay_UsersStatisticsByIP]
	@fromdate		DATETIME
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
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @RowStart INT, @RowEnd INT
	SELECT  @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1
	
	IF @max_transid = 0
		SELECT @max_transid = MAX(transid) FROM rmBettrans WITH (NOLOCK)
	
	SELECT @totalItems = COUNT(1)
	FROM
	(
		SELECT IP
		FROM dbo.rmBettrans WITH (NOLOCK)
		WHERE transdate >= @fromdate AND transdate < DATEADD(DAY, 1, @fromdate)
		GROUP BY IP
		HAVING COUNT(DISTINCT custid) >= 2
	) r
	
	SELECT IP, cntUsers
	FROM
	(
		SELECT IP, cntUsers, ROW_NUMBER() OVER(ORDER BY cntUsers DESC) AS rn
		FROM
		(
			SELECT IP, COUNT(DISTINCT custid) AS cntUsers
			FROM rmBettrans WITH(NOLOCK)
			WHERE transdate >= @fromdate AND transdate < DATEADD(DAY, 1, @fromdate)
			GROUP BY IP
			HAVING COUNT(DISTINCT custid) >= 2
		) r
	) t
	WHERE rn BETWEEN @RowStart AND @RowEnd
END 
GO