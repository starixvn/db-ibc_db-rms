/*<info serverAlias="DBRMS-bodb_RMS" isFunction="0" isNested="1"></info>*/
CREATE PROCEDURE [dbo].[Task_RMS_MBU_CopyData_rmBettrans]
	@winlostdate SMALLDATETIME
	,@ErrCode		INT = 0 OUTPUT
	,@ErrMsg		VARCHAR(4000) = '' OUTPUT
AS

/*
	Created: 20200512@Percy
	DB: DBRMS-bodb_RMS
	Task: RMS - Copy data from rmBettrans to rmBettrans_Old

	Revisions:
		- 20200512@Percy: Initialize SP [RedmineID: #130275]
		- 20201214@Danny: Separate Data of Virtual Soccer & Virtual Basketball [RedmineID: #145926]
		- 20231020@Cherry: Parlay Generator (#195498)
*/

BEGIN
	SET NOCOUNT ON

	CREATE TABLE #TransId (transid BIGINT PRIMARY KEY)
	INSERT INTO #TransId (transid)
	SELECT transid FROM dbo.rmBettrans WITH (NOLOCK) WHERE winlostdate = @winlostdate

	IF @@ROWCOUNT = 0
		RETURN

	IF EXISTS (SELECT 1 FROM dbo.rmBettrans_Old WITH (NOLOCK) WHERE winlostdate = @winlostdate)
		DELETE dbo.rmBettrans_Old WITH (ROWLOCK, UPDLOCK) WHERE winlostdate = @winlostdate

	DELETE o WITH (ROWLOCK, UPDLOCK)
	FROM dbo.rmBettrans_Old o
		INNER JOIN #TransId t ON o.transid = t.transid

	BEGIN TRY
		INSERT INTO dbo.rmBettrans_Old
		(
			transid,custid,transdate,oddsid,hdp1,hdp2,odds,stake,status,winlost,awinlost,mwinlost,playercomm,comm,acomm
			,apositiontaking,mpositiontaking,tpositiontaking,playerdiscount,discount,adiscount,livehomescore,liveawayscore
			,liveindicator,betteam,creator,refno,comstatus,winlostdate,betfrom,betcheck,checktime,oddsspread,actualrate,matchid
			,recommend,mrecommend,ruben,betid,statuswinlost,modds,bettype,betdaqid,actual_stake,currency,ip,transdesc
			,sdiscount,scomm,spositiontaking,swinlost,srecommend,Username,CurrencyName,virtualrate,oddstype,statusID,currency2
			,balance,SecAcceptFlag,transid2,combo,odds2,TotalBet,epositiontaking,ExtraInfo
		)
		SELECT
			transid,custid,transdate,oddsid,hdp1,hdp2,odds,stake,status,winlost,awinlost,mwinlost,playercomm,comm,acomm
			,apositiontaking,mpositiontaking,tpositiontaking,playerdiscount,discount,adiscount,livehomescore,liveawayscore
			,liveindicator,betteam,creator,refno,comstatus,winlostdate,betfrom,betcheck,checktime,oddsspread,actualrate,matchid
			,recommend,mrecommend,ruben,betid,statuswinlost,modds,bettype,betdaqid,actual_stake,currency,ip,transdesc
			,sdiscount,scomm,spositiontaking,swinlost,srecommend,Username,CurrencyName,virtualrate,oddstype,statusID,currency2
			,balance,SecAcceptFlag,transid2,combo,odds2,TotalBet,epositiontaking,ExtraInfo
		FROM dbo.rmBettrans r WITH (NOLOCK)
		WHERE EXISTS (SELECT 1 FROM #TransId t WHERE r.transid = t.transid)
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = 101, @ErrMsg = ERROR_MESSAGE()
		RETURN
	END CATCH
END
GO