/*<info serverAlias="DBACC-bodb02"></info>*/
/*
	Created: 20200824@Percy
	DB: DBACC-bodb02
	Task: PRMS - Grant execute permission on Age_SelBalanceUpDay to bodbRMSNet
*/
use bodb02
go

grant execute on dbo.Age_SelBalanceUpDay to bodbRMSNet as dbo
go 