 /*
	Created: Winnie
	Date: 2016-05-23
	Task: Correct data RMS
	DB: DBRMS/bodb_RMS
*/
USE bodb_RMS
GO

UPDATE [rmSumWinloss_OLD]
SET sporttype=-1 WHERE sporttype=2

UPDATE [rmSumWinloss_OLD]
SET sporttype=-3 WHERE sporttype=3
	