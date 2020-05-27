/*<info serverAlias="DBRMS-bodb_RMS"></info>*/

/*
	Created: 20200512@Percy
	DB: DBRMS-bodb_RMS
	Task: Initialize data for new table: rmBettrans_Old

	Step 3: Insert data from temp table
*/

USE bodb_RMS
GO

DECLARE @winlostdate SMALLDATETIME = '2020-03-01'
DECLARE @errMsg VARCHAR(200) = ''

WHILE @winlostdate < '2020-05-15'
BEGIN
	SELECT @errMsg = 'Start run date = ' + CONVERT(VARCHAR(10), @winlostdate, 120)
	RAISERROR (@errMsg, 1, 0) WITH NOWAIT

	DELETE dbo.rmBettrans_Old WITH (ROWLOCK, UPDLOCK) WHERE winlostdate = @winlostdate

	INSERT INTO dbo.rmBettrans_Old
	(
		transid,custid,transdate,oddsid,hdp1,hdp2,odds,stake,status,winlost,awinlost,mwinlost,playercomm,comm,acomm
		,apositiontaking,mpositiontaking,tpositiontaking,playerdiscount,discount,adiscount,livehomescore,liveawayscore
		,liveindicator,betteam,creator,refno,comstatus,winlostdate,betfrom,betcheck,checktime,oddsspread,actualrate,matchid
		,recommend,mrecommend,ruben,betid,statuswinlost,modds,bettype,betdaqid,actual_stake,currency,ip,transdesc
		,sdiscount,scomm,spositiontaking,swinlost,srecommend,Username,CurrencyName,virtualrate,oddstype,statusID,currency2
		,balance,SecAcceptFlag,epositiontaking,transid2,combo,odds2,TotalBet
	)
	SELECT
		transid,custid,transdate,oddsid,hdp1,hdp2,odds,stake,status,winlost,awinlost,mwinlost,playercomm,comm,acomm
		,apositiontaking,mpositiontaking,tpositiontaking,playerdiscount,discount,adiscount,livehomescore,liveawayscore
		,liveindicator,betteam,creator,refno,comstatus,winlostdate,betfrom,betcheck,checktime,oddsspread,actualrate,matchid
		,recommend,mrecommend,ruben,betid,statuswinlost,modds,bettype,betdaqid,actual_stake,currency,ip,transdesc
		,sdiscount,scomm,spositiontaking,swinlost,srecommend,Username,CurrencyName,virtualrate,oddstype,statusID,currency2
		,balance,SecAcceptFlag,epositiontaking,transid2,combo,odds2,TotalBet
	FROM DBARC.bodb_Archive.dbo.rmBettrans_Old_Test WITH (NOLOCK)
	WHERE winlostdate = @winlostdate

	SELECT @winlostdate = DATEADD(DAY, 1, @winlostdate)

	WAITFOR DELAY '00:00:00.280'
END
