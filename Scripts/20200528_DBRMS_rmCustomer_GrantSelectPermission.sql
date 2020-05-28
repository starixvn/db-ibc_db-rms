/*<info serverAlias="DBRMS-bodb_RMS"></info>*/
/*
	Created: 20200528@Percy
	DB: DBRMS-bodb_RMS
	Task: PRMS - Grant select permission on rmCustomer table to bodbRMSNet
*/

USE bodb_RMS
GO

GRANT SELECT ON dbo.rmCustomer TO bodbRMSNet AS dbo
GO