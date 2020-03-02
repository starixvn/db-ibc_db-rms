USE bodb_RMS
GO

/*
	Created: 20200203@Percy
	DB: DBRMS.bodb_RMS
	Task: Add new column epositiontaking on rmBettrans
*/

ALTER TABLE dbo.rmBettrans
	ADD epositiontaking SMALLMONEY
GO