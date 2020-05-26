/*<info serverAlias="DBRMS-bodb_RMS"></info>*/
USE msdb
GO

/*
	Created: 20200512@Percy
	DB: DBRMS-msdb
	Task: Enable new jobs
	Remark: Please deploy SP package first
*/

-- copy and sum data
EXEC sp_update_job
	@job_name = N'bodb_RMS: Copy & Sum Data',
	@enabled = 1
GO

-- check sum and delete data
EXEC sp_update_job
	@job_name = N'bodb_RMS: Check Sum & Delete Data',
	@enabled = 1
GO