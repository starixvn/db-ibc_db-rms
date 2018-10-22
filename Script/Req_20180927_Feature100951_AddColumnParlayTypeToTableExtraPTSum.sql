/*
		Created: Jacob
		Date: 2018-09-27
		Task: Apply Extra PT and Super Comm to Report.  RedmineID: #100951
		DB: DBRMS/bodb_RMS
		
		Revisions:
			- 20180927@Jacob: Apply Extra PT and Super Comm to Report.  RedmineID: #100951 		
		Parameter's Explanation:
*/

USE [bodb_RMS]
GO

TRUNCATE TABLE rmSumWinlossExtraPT;
GO

ALTER TABLE rmSumWinlossExtraPT
ADD [parlaytype] [tinyint] NULL;
GO

TRUNCATE TABLE rmSumWinlossExtraPT_Old;
GO

ALTER TABLE rmSumWinlossExtraPT_Old
ADD [parlaytype] [tinyint] NULL;
GO

