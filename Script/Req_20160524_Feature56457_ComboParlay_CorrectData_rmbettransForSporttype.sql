 /*
	Created: Winnie
	Date: 2016-05-23
	Task: Correct data RMS
	DB: DBRMS/bodb_RMS
*/
USE bodb_RMS
GO

update rmBettrans
SET transid2=-1
WHERE liveawayscore =2

update rmBettrans
SET transid2=1
WHERE liveawayscore =1

update rmBettrans
SET transid2=-3
WHERE liveawayscore =3

