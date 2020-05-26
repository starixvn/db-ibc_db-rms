/*<info serverAlias="DBRMS-bodb_RMS"></info>*/
/*
	Created: 20200512@Percy
	DB: DBRMS-bodb_RMS
	Task: PRMS - New table to store parlay tickets from rmBettrans (keep 3 months data)
*/

USE bodb_RMS
GO

CREATE TABLE dbo.rmBettrans_Old
(
	transid bigint NOT NULL,
	custid int NOT NULL,
	transdate datetime NOT NULL,
	oddsid int NOT NULL,
	hdp1 smallmoney NULL,
	hdp2 smallmoney NULL,
	odds smallmoney NULL,
	stake money NOT NULL,
	status nvarchar(10) NULL,
	winlost money NULL,
	awinlost money NULL,
	mwinlost money NULL,
	playercomm money NULL,
	comm money NULL,
	acomm money NULL,
	apositiontaking smallmoney NULL,
	mpositiontaking smallmoney NULL,
	tpositiontaking smallmoney NULL,
	playerdiscount decimal(9, 8) NULL,
	discount decimal(9, 8) NULL,
	adiscount decimal(9, 8) NULL,
	livehomescore smallint NULL,
	liveawayscore smallint NULL,
	liveindicator bit NULL,
	betteam nvarchar(10) NULL,
	creator int NOT NULL,
	refno bigint NOT NULL,
	comstatus nvarchar(20) NULL,
	winlostdate smalldatetime NULL,
	betfrom nvarchar(1) NULL,
	betcheck nvarchar(50) NULL,
	checktime datetime NULL,
	oddsspread smallmoney NULL,
	actualrate float NULL,
	matchid int NULL,
	recommend int NOT NULL,
	mrecommend int NOT NULL,
	ruben tinyint NULL,
	betid bigint NULL,
	statuswinlost tinyint NULL,
	modds smallmoney NULL,
	bettype smallint NULL,
	betdaqid bigint NULL,
	tstamp timestamp NULL,
	actual_stake money NULL,
	currency tinyint NULL,
	ip nvarchar(15) NULL,
	transdesc nvarchar(1000) NULL,
	sdiscount decimal(9, 8) NULL,
	scomm money NULL,
	spositiontaking smallmoney NULL,
	swinlost money NULL,
	srecommend int NOT NULL,
	Username nvarchar(50) NULL,
	CurrencyName nvarchar(50) NULL,
	virtualrate float NOT NULL,
	oddstype tinyint NULL,
	statusID tinyint NULL,
	currency2 tinyint NULL,
	balance money NULL,
	SecAcceptFlag bit NULL,
	transid2 bigint NULL,
	combo int NULL,
	odds2 money NULL,
	TotalBet int NULL,
	epositiontaking smallmoney NULL,
	CONSTRAINT PK_rmBettrans_Old PRIMARY KEY NONCLUSTERED
	(
		transid ASC
	) ON [rmDATA]
) ON [rmDATA]
GO

CREATE CLUSTERED INDEX CIX_rmBettrans_Old ON dbo.rmBettrans_Old
(
	winlostdate ASC,
	bettype ASC,
	statusID ASC
) ON [rmDATA]
GO