/*<info serverAlias="DBRMS-bodb_RMS"></info>*/

/*
	Created: 20200512@Percy
	DB: DBRMS-bodb_RMS
	Task: Regen data rmSumWinloss on 21 and 22 May 2020
*/

USE bodb_RMS
GO

EXEC dbo.Task_RMS_CheckSumData_rmSumWinloss @winlostdate = '2020-05-21'
GO

EXEC dbo.Task_RMS_CheckSumData_rmSumWinloss @winlostdate = '2020-05-22'
GO