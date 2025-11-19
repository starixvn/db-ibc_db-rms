/*<info serverAlias="DBRMS-bodb_RMS" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Task_RMS_MBU_CheckSumData_Job]
AS

/*
	Created: 20200512@Percy
	DB: DBRMS-bodb_RMS
	Task: RMS - Check Sum data

	Revisions:
		- 20200512@Percy: Initialize SP [RedmineID: #130275]
		- 20201214@Danny: Separate Data of Virtual Soccer & Virtual Basketball [RedmineID: #145926]
		- 20230530@Cherry: Void tickets in bettrans14 (#188647)
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @FromDate SMALLDATETIME, @ToDate SMALLDATETIME
	DECLARE @winlostdate SMALLDATETIME, @ErrCode INT, @ErrMsg NVARCHAR(4000)
	DECLARE @tblErrMsg TABLE (TableName VARCHAR(300), ErrMsg VARCHAR(4000))

	DECLARE @MBSchedule TABLE (Id TINYINT, winlostdate SMALLDATETIME)
	INSERT INTO @MBSchedule (Id, winlostdate)
	EXEC DBTXN.bodb02.dbo.Task_MoveBetsDayByScheduleSel

	DECLARE @info table (BU SMALLDATETIME, MB SMALLDATETIME)
    INSERT INTO @info (BU, MB)
	EXEC bodb02.dbo.Age_SelBalanceUpDay

    DECLARE @MoveBetsDay SMALLDATETIME, @BalanceUpDay SMALLDATETIME
    SELECT @MoveBetsDay = MB, @BalanceUpDay = BU			
	FROM @info

	DECLARE @tmpDate SMALLDATETIME
	SELECT @tmpDate = @MoveBetsDay

	WHILE @tmpDate >= DATEADD(DAY, -4, @MoveBetsDay) AND @tmpDate >= @BalanceUpDay
	BEGIN
		INSERT INTO @MBSchedule (winlostdate) 
		SELECT @tmpDate WHERE @tmpDate NOT IN (SELECT winlostdate FROM @MBSchedule)

		SELECT @tmpDate = DATEADD(DAY, -1, @tmpDate)
	END

	-- rmBettrans_Old
	BEGIN
		SELECT @FromDate = NULL, @ToDate = NULL, @winlostdate = NULL, @ErrCode = 0, @ErrMsg = ''

		SELECT @FromDate = MIN(winlostdate), @ToDate = MAX(winlostdate) FROM @MBSchedule
	
		SELECT @winlostdate = @FromDate
		WHILE  @winlostdate <= @ToDate
		BEGIN
			EXEC dbo.Task_RMS_MBU_CheckSumData_rmBettrans_Old @winlostdate = @winlostdate, @ErrCode = @ErrCode OUTPUT, @ErrMsg = @ErrMsg OUTPUT
			IF @ErrCode > 0
			BEGIN
				INSERT INTO @tblErrMsg (TableName, ErrMsg)
				SELECT 'rmBettrans_Old', 'From winlostdate = ''''' + CONVERT(VARCHAR(10), @winlostdate, 120) + '''' + ' - ' + ISNULL(@ErrMsg , '')

				BREAK
			END

			SELECT @winlostdate = DATEADD(DAY, 1, @winlostdate)
		END
	END

	-- rmSum_Winloss
	BEGIN
		SELECT @FromDate = NULL, @ToDate = NULL, @winlostdate = NULL, @ErrCode = 0, @ErrMsg = ''

		SELECT @FromDate = MIN(winlostdate), @ToDate = MAX(winlostdate) FROM @MBSchedule
	
		SELECT @winlostdate = @FromDate
		WHILE  @winlostdate <= @ToDate
		BEGIN
			SELECT @ErrCode = 0, @ErrMsg = ''

			EXEC dbo.Task_RMS_MBU_CheckSumData_rmSumWinloss @winlostdate = @winlostdate, @ErrCode = @ErrCode OUTPUT, @ErrMsg = @ErrMsg OUTPUT

			IF @ErrCode > 0
			BEGIN
				INSERT INTO @tblErrMsg (TableName, ErrMsg)
				SELECT 'rmSumWinloss', 'From winlostdate = ''''' + CONVERT(VARCHAR(10), @winlostdate, 120) + '''' + ' - ' + ISNULL(@ErrMsg , '')

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

		SELECT @ErrMsg = 'Failed to CHECKSUM data' + CHAR(13) + @ErrMsg

		RAISERROR (@ErrMsg, 16, 1)
		RETURN
	END
END
GO