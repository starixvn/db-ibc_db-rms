/*<info serverAlias="DBRMS-bodb_RMS"></info>*/
USE msdb
GO

/*
	Created: 20200512@Percy
	DB: DBRMS-msdb
	Task:
		1. Merge job [bodb_RMS: SumWinloss & Archive] and [bodb_RMS: Clean OLD data from BettransParlay]
		2. Revise job: copy data first then delete data
		3. Add table rmBettrans_Old
*/

-- Remove old job
EXEC sp_delete_job @job_name = N'bodb_RMS: SumWinloss & Archive'
GO

EXEC sp_delete_job @job_name = N'bodb_RMS: Clean OLD data from BettransParlay'
GO

-- New job copy and sum data
EXEC sp_add_job
	@job_name = N'bodb_RMS: Copy & Sum Data',
	@enabled = 0,
	@notify_level_eventlog = 0,
	@notify_level_email = 0,
	@notify_level_netsend = 0,
	@notify_level_page = 0,
	@delete_level = 0,
	@description = N'No description available.',
	@category_name = N'[Uncategorized (Local)]',
	@owner_login_name = N'sa'
GO

EXEC sp_add_jobstep
	@job_name = N'bodb_RMS: Copy & Sum Data',
	@step_id = 1,
	@step_name = N'Copy data',
	@on_success_action = 3,
	@on_success_step_id = 0,
	@on_fail_action = 2,
	@on_fail_step_id = 0,
	@subsystem = N'TSQL', 
	@command = N'EXEC dbo.Task_RMS_CopyData_Job', 
	@database_name = N'bodb_RMS'
GO

EXEC sp_add_jobstep
	@job_name = N'bodb_RMS: Copy & Sum Data',
	@step_id = 2,
	@step_name = N'Sum data',
	@on_success_action = 1,
	@on_success_step_id = 0,
	@on_fail_action = 2,
	@on_fail_step_id = 0,
	@subsystem = N'TSQL', 
	@command = N'EXEC dbo.Task_RMS_SumData_Job', 
	@database_name = N'bodb_RMS'
GO

EXEC sp_update_job
	@job_name = N'bodb_RMS: Copy & Sum Data',
	@start_step_id = 1

EXEC sp_add_jobschedule
	@job_name = N'bodb_RMS: Copy & Sum Data',
	@name = N'Daily',
	@enabled = 1,
	@freq_type = 4,
	@freq_interval = 1,
	@freq_subday_type = 1,
	@freq_subday_interval = 0,
	@freq_relative_interval = 0,
	@freq_recurrence_factor = 0,
	@active_start_date = 20200512,
	@active_end_date = 99991231,
	@active_start_time = 53000,
	@active_end_time = 235959
GO

EXEC sp_add_jobserver
	@job_name = N'bodb_RMS: Copy & Sum Data',
	@server_name = N'(local)'
GO

-- New job check sum and delete data
EXEC sp_add_job
	@job_name = N'bodb_RMS: Check Sum & Delete Data',
	@enabled = 0,
	@notify_level_eventlog = 0,
	@notify_level_email = 0,
	@notify_level_netsend = 0,
	@notify_level_page = 0,
	@delete_level = 0,
	@description = N'No description available.',
	@category_name = N'[Uncategorized (Local)]',
	@owner_login_name = N'sa'
GO

EXEC sp_add_jobstep
	@job_name = N'bodb_RMS: Check Sum & Delete Data',
	@step_id = 1,
	@step_name = N'Check Move Bets Finish',
	@on_success_action = 4,
	@on_success_step_id = 3,
	@on_fail_action = 4,
	@on_fail_step_id = 2,
	@subsystem = N'TSQL', 
	@command = N'EXEC dbo.Task_MoveBets_Status_Job', 
	@database_name = N'bodb02'
GO

EXEC sp_add_jobstep
	@job_name = N'bodb_RMS: Check Sum & Delete Data',
	@step_id = 2,
	@step_name = N'Delay 15 minutes',
	@on_success_action = 4,
	@on_success_step_id = 1,
	@on_fail_action = 2,
	@on_fail_step_id = 0,
	@subsystem = N'TSQL', 
	@command = N'WAITFOR DELAY ''00:15:00.000''', 
	@database_name = N'bodb02'
GO

EXEC sp_add_jobstep
	@job_name = N'bodb_RMS: Check Sum & Delete Data',
	@step_id = 3,
	@step_name = N'Check Sum data',
	@on_success_action = 3,
	@on_success_step_id = 0,
	@on_fail_action = 2,
	@on_fail_step_id = 0,
	@subsystem = N'TSQL', 
	@command = N'EXEC dbo.Task_RMS_CheckSumData_Job', 
	@database_name = N'bodb_RMS'
GO

EXEC sp_add_jobstep
	@job_name = N'bodb_RMS: Check Sum & Delete Data',
	@step_id = 4,
	@step_name = N'Delete data',
	@on_success_action = 1,
	@on_success_step_id = 0,
	@on_fail_action = 2,
	@on_fail_step_id = 0,
	@subsystem = N'TSQL', 
	@command = N'EXEC dbo.Task_RMS_DeleteData_Job', 
	@database_name = N'bodb_RMS'
GO

EXEC sp_update_job
	@job_name = N'bodb_RMS: Check Sum & Delete Data',
	@start_step_id = 1
GO

EXEC sp_add_jobschedule
	@job_name = N'bodb_RMS: Check Sum & Delete Data',
	@name = N'Daily',
	@enabled = 1,
	@freq_type = 4,
	@freq_interval = 1,
	@freq_subday_type = 1,
	@freq_subday_interval = 0,
	@freq_relative_interval = 0,
	@freq_recurrence_factor = 0,
	@active_start_date = 20200512,
	@active_end_date = 99991231,
	@active_start_time = 201500,
	@active_end_time = 235959
GO

EXEC sp_add_jobserver
	@job_name = N'bodb_RMS: Check Sum & Delete Data',
	@server_name = N'(local)'
GO