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

ALTER TABLE rmSumWinloss
ADD [scomm] [money] NULL;
GO

ALTER TABLE rmSumWinloss
ADD [Extra_comm] [money] NULL;
GO

ALTER TABLE rmSumWinloss
ADD [Extra_stake] [money] NULL;
GO

ALTER TABLE rmSumWinloss
ADD [Extra_winlost] [money] NULL;
GO

ALTER TABLE rmSumWinloss_Old
ADD [scomm] [money] NULL;
GO

ALTER TABLE rmSumWinloss_Old
ADD [Extra_comm] [money] NULL;
GO

ALTER TABLE rmSumWinloss_Old
ADD [Extra_stake] [money] NULL;
GO

ALTER TABLE rmSumWinloss_Old
ADD [Extra_winlost] [money] NULL;
GO



