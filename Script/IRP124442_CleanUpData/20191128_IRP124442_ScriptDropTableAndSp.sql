/*
	Created: 20191128@Johnson
	Task: clean up RMS [redmine:#124442]
	DB: DBRMS/bodb_RMS
*/

--drop sps and tables
DROP PROC 	RMS_Similar_Parlay_Betlist_xtest_DEL
DROP PROC 	RMS_Similar_Parlay_Betlist_DEL
DROP PROC 	Task_RMS_TransactionIns_DEL
DROP PROC 	Task_RMS_Transaction_Archive_DEL
DROP PROC 	RMS_Monitor_Parlay_Betlist_xpre_DEL
DROP PROC 	RMS_Similar_Parlay_Betlist_xpre_DEL
DROP PROC 	Task_RMS_TransactionIns_xtest_DEL

DROP TABLE rmTransaction_DEL
DROP TABLE rmTransaction_bk_DEL
