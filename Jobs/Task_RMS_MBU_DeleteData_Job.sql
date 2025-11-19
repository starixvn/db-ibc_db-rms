/*<info serverAlias="DBRMS-bodb_RMS" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Task_RMS_MBU_DeleteData_Job]	
AS

/*
	Created: 20200512@Percy
	DB: DBRMS-bodb_RMS
	Task: RMS - Remove data

	Revisions:
		- 20200512@Percy: Initialize SP [RedmineID: #130275]
		- 20201214@Danny: Separate Data of Virtual Soccer & Virtual Basketball [RedmineID: #145926]
		- 20210319@Danny: Add function to copy data of bettransm_bk, match_bk [RedmineID: #151319]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @FromDate SMALLDATETIME, @ToDate SMALLDATETIME
	DECLARE @winlostdate SMALLDATETIME, @ErrCode INT, @ErrMsg VARCHAR(4000)
	DECLARE @tblErrMsg TABLE (TableName VARCHAR(300), ErrMsg VARCHAR(4000))

	DECLARE @MBBU TABLE (BalanceUpDay SMALLDATETIME, MoveBetsDay SMALLDATETIME)
	INSERT INTO @MBBU (BalanceUpDay, MoveBetsDay)
	EXEC bodb02.dbo.Age_SelBalanceUpDay

	-- rmBettrans
	BEGIN
		SELECT @FromDate = NULL, @ToDate = NULL, @winlostdate = NULL, @ErrCode = 0, @ErrMsg = ''

		SELECT  @FromDate = MIN(winlostdate) FROM dbo.rmBettrans WITH (NOLOCK)
		SELECT  @ToDate = MoveBetsDay FROM @MBBU

		SELECT @winlostdate = @FromDate
		WHILE  @winlostdate <= @ToDate
		BEGIN
			EXEC dbo.Task_RMS_MBU_DeleteData_rmBettrans @winlostdate = @winlostdate, @ErrCode = @ErrCode OUTPUT, @ErrMsg = @ErrMsg OUTPUT

			IF @ErrCode > 0
			BEGIN
				INSERT INTO @tblErrMsg (TableName, ErrMsg)
				SELECT 'rmBettrans', 'From winlostdate = ''''' + CONVERT(VARCHAR(10), @winlostdate, 120) + '''' + ' - ' + ISNULL(@ErrMsg , '')

				BREAK
			END

			SELECT @winlostdate = DATEADD(DAY, 1, @winlostdate)
		END
	END

	-- rmBettrans_Old
	BEGIN
		SELECT @FromDate = NULL, @ToDate = NULL, @winlostdate = NULL, @ErrCode = 0, @ErrMsg = ''

		SELECT  @FromDate = MIN(winlostdate) FROM dbo.rmBettrans_Old WITH (NOLOCK)
		SELECT  @ToDate = DATEADD(DAY, -1, DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()) - 3, 0)) -- Keep data in 3 months (from 1st)

		SELECT @winlostdate = @FromDate
		WHILE  @winlostdate <= @ToDate
		BEGIN
			EXEC dbo.Task_RMS_MBU_DeleteData_rmBettransOld @winlostdate = @winlostdate, @ErrCode = @ErrCode OUTPUT, @ErrMsg = @ErrMsg OUTPUT

			IF @ErrCode > 0
			BEGIN
				INSERT INTO @tblErrMsg (TableName, ErrMsg)
				SELECT 'rmBettrans_Old', 'From winlostdate = ''''' + CONVERT(VARCHAR(10), @winlostdate, 120) + '''' + ' - ' + ISNULL(@ErrMsg , '')

				BREAK
			END

			SELECT @winlostdate = DATEADD(DAY, 1, @winlostdate)
		END
	END

	-- rmSumWinloss
	BEGIN
		SELECT @FromDate = NULL, @ToDate = NULL, @winlostdate = NULL, @ErrCode = 0, @ErrMsg = ''

		SELECT  @FromDate = MIN(winlostdate) FROM dbo.rmSumWinloss WITH (NOLOCK)
		SELECT  @ToDate = DATEADD(DAY, -1, BalanceUpDay) FROM @MBBU

		SELECT @winlostdate = @FromDate
		WHILE  @winlostdate <= @ToDate
		BEGIN
			EXEC dbo.Task_RMS_MBU_DeleteData_rmSumWinloss @winlostdate = @winlostdate, @ErrCode = @ErrCode OUTPUT, @ErrMsg = @ErrMsg OUTPUT

			IF @ErrCode > 0
			BEGIN
				INSERT INTO @tblErrMsg (TableName, ErrMsg)
				SELECT 'rmSumWinloss', 'From winlostdate = ''''' + CONVERT(VARCHAR(10), @winlostdate, 120) + '''' + ' - ' + ISNULL(@ErrMsg , '')

				BREAK
			END

			SELECT @winlostdate = DATEADD(DAY, 1, @winlostdate)
		END
	END


	-- rmBettransm_bk, rmMatch_bk
	BEGIN
		SELECT @FromDate = NULL, @ToDate = NULL, @winlostdate = NULL, @ErrCode = 0, @ErrMsg = ''

		SELECT  @FromDate = MIN(winlostdate) FROM dbo.rmBettransm_bk WITH (NOLOCK)
		SELECT  @ToDate = DATEADD(DAY, -30, BalanceUpDay) FROM @MBBU -- Keep data in 30 days (from previous BU date)

		SELECT @winlostdate = @FromDate
		WHILE  @winlostdate <= @ToDate
		BEGIN
			EXEC dbo.Task_RMS_MBU_DeleteData_rmBettransm_bk @winlostdate = @winlostdate, @ErrCode = @ErrCode OUTPUT, @ErrMsg = @ErrMsg OUTPUT

			IF @ErrCode > 0
			BEGIN
				INSERT INTO @tblErrMsg (TableName, ErrMsg)
				SELECT 'rmBettransm_bk', 'From winlostdate = ''''' + CONVERT(VARCHAR(10), @winlostdate, 120) + '''' + ' - ' + ISNULL(@ErrMsg , '')

				BREAK
			END

			SELECT @winlostdate = DATEADD(DAY, 1, @winlostdate)
		END
	END


	IF EXISTS (SELECT 1 FROM @tblErrMsg)
	BEGIN
		SELECT @ErrMsg = NULL
		SELECT @ErrMsg = COALESCE(@ErrMsg + CHAR(13), '') + TableName + ' - ' + ErrMsg
		FROM @tblErrMsg

		SELECT @ErrMsg = 'Failed to DELETE data' + CHAR(13) + @ErrMsg

		RAISERROR (@ErrMsg, 16, 1)
		RETURN
	END
END
GO