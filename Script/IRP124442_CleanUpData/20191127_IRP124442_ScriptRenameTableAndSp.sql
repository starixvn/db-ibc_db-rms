/*
	Created: 20191127@Johnson
	Task: clean up RMS [redmine:#124442]
	DB: DBRMS/bodb_RMS
*/

--step 1: remove step 5 of job bodb_RMS: SumWinloss & Archive
  
EXEC msdb.dbo.sp_delete_jobstep  
    @job_name = N'bodb_RMS: SumWinloss & Archive',  
    @step_id = 5 ;  -- EXEC [dbo].[Task_RMS_Transaction_Archive]  
GO  

EXEC msdb.dbo.sp_update_jobstep  
    @job_name = N'bodb_RMS: SumWinloss & Archive',  
    @step_id = 4,    
    @on_success_action = 1 --Quit with success.

	
--step 2: rename sps list & tables
EXEC sp_rename 	'RMS_Similar_Parlay_Betlist_xtest',	'RMS_Similar_Parlay_Betlist_xtest_DEL'
EXEC sp_rename 	'RMS_Similar_Parlay_Betlist',	'RMS_Similar_Parlay_Betlist_DEL'
EXEC sp_rename 	'Task_RMS_TransactionIns',	'Task_RMS_TransactionIns_DEL'
EXEC sp_rename 	'Task_RMS_TransactionInsLoop',	'Task_RMS_TransactionInsLoop_DEL'
EXEC sp_rename 	'Task_RMS_Transaction_Archive',	'Task_RMS_Transaction_Archive_DEL'
EXEC sp_rename 	'RMS_Monitor_Parlay_Betlist_xpre',	'RMS_Monitor_Parlay_Betlist_xpre_DEL'
EXEC sp_rename 	'RMS_Similar_Parlay_Betlist_xpre',	'RMS_Similar_Parlay_Betlist_xpre_DEL'
EXEC sp_rename 	'Task_RMS_TransactionIns_xtest',	'Task_RMS_TransactionIns_xtest_DEL'

EXEC sp_rename 	'rmTransaction','rmTransaction_DEL'
EXEC sp_rename 	'rmTransaction_bk', 'rmTransaction_bk_DEL'

