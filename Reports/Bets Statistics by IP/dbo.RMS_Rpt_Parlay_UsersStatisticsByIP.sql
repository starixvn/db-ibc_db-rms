ALTER PROCEDURE [dbo].[RMS_Rpt_Parlay_UsersStatisticsByIP]
	@fromdate	DATETIME,
	@pageIndex	INT = 1,
	@pageSize	INT = 100,
	@totalItems INT = 0 OUTPUT,
	@max_transid BIGINT = 0 OUTPUT
AS
	/*
		Created: Johnson
		Date: 2014-06-30
		Task: IP statistics by users
		DB: DBRMS/bodb_RMS
		
		Parameter's Explanation:
		
		Revisions:
	*/
BEGIN
	SET NOCOUNT ON
	DECLARE @RowStart int, @RowEnd int, @todate DATETIME
	
	SELECT @todate = @fromdate + '23:59:59'
	
	SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1 
	
	IF @max_transid = 0
	BEGIN
		SELECT @max_transid = MAX(transid) FROM rmBettrans WITH(NOLOCK)
	END
	
	IF @totalItems = 0
	BEGIN
		SELECT @totalItems = COUNT(1)
		from (
			select ip
			FROM rmBettrans WITH(NOLOCK)
			WHERE transdate between @fromdate and @todate
				AND transid <= @max_transid			
			GROUP BY IP
			HAVING COUNT(DISTINCT custid)>=2
		)r
	END
	
	SELECT IP, cntUsers
	FROM (	
		SELECT IP, COUNT(DISTINCT custid) as cntUsers, ROW_NUMBER() OVER(ORDER BY COUNT(DISTINCT custid) DESC) rn
		FROM rmBettrans WITH(NOLOCK)
		WHERE transdate between @fromdate and @todate
			AND transid <= @max_transid		
		GROUP BY IP
		HAVING COUNT(DISTINCT custid)>=2
	)t
	WHERE rn between @RowStart and @RowEnd
END 
GO

GRANT EXECUTE ON [dbo].[RMS_Rpt_Parlay_UsersStatisticsByIP] TO [bodbRMSNet]
GO
