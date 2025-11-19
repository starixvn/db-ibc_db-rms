/*<info serverAlias="DBRMS-bodb_RMS" isFunction="0" isNested="1"></info>*/
ALTER PROCEDURE [dbo].[Task_RMS_MBU_CopyData_rmSumWinloss]
	@winlostdate SMALLDATETIME
	,@ErrCode		INT = 0 OUTPUT
	,@ErrMsg		VARCHAR(4000) = '' OUTPUT
AS

/*
	Created: 20200512@Percy
	DB: DBRMS-bodb_RMS
	Task: RMS - Copy data from rmSumWinloss to rmSumWinloss_Old

	Revisions:
		- 20200512@Percy: Initialize SP [RedmineID: #130275]
		- 20201214@Danny: Separate Data of Virtual Soccer & Virtual Basketball [RedmineID: #145926]
*/

BEGIN
	SET NOCOUNT ON

	IF NOT EXISTS (SELECT 1 FROM dbo.rmSumWinloss WITH (NOLOCK) WHERE winlostdate = @winlostdate)
		RETURN

	IF EXISTS (SELECT 1 FROM dbo.rmSumWinloss_Old WITH (NOLOCK) WHERE winlostdate = @winlostdate)
		DELETE dbo.rmSumWinloss_Old WITH (ROWLOCK, UPDLOCK) WHERE winlostdate = @winlostdate

	BEGIN TRY
		INSERT INTO dbo.rmSumWinloss_Old
		(
			winlostdate,custid,sporttype,statusid,combo,username,currency,stake,winlost,company_stake,company_winlost
			,actualrate,odds,betcount,recommend,parlaytype,scomm,Extra_comm,Extra_stake,Extra_winlost,
			mrecommend,srecommend,awinlost,mwinlost,swinlost,actual_stake,playercomm,comm,acomm, liveindicator

		)
		SELECT
			winlostdate,custid,sporttype,statusid,combo,username,currency,stake,winlost,company_stake,company_winlost
			,actualrate,odds,betcount,recommend,parlaytype,scomm,Extra_comm,Extra_stake,Extra_winlost,
			mrecommend,srecommend,awinlost,mwinlost,swinlost,actual_stake,playercomm,comm,acomm, liveindicator
		FROM dbo.rmSumWinloss WITH (NOLOCK)
		WHERE winlostdate = @winlostdate
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = 101, @ErrMsg = ERROR_MESSAGE()
		RETURN
	END CATCH
END
GO