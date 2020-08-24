/*<info serverAlias="DBRMS-bodb_RMS"></info>*/
/*
	Created: 20200824@Percy
	DB: DBRMS-bodb_RMS
	Task: Add column JobType to support many jobs
*/

use bodb_RMS
go

alter table dbo.rmLastTicketAlert
	add JobType tinyint constraint DF_rmLastTicketAlert_JobType default ((1))
go

-- 2809 rows
update dbo.rmLastTicketAlert with (rowlock)
set JobType = 1
go

alter table dbo.rmLastTicketAlert
	alter column JobType tinyint not null
go

alter table dbo.rmLastTicketAlert
	drop constraint PK_rmLastTicketAlert
go

alter table dbo.rmLastTicketAlert
	add constraint PK_rmLastTicketAlert primary key
	(
		TransId asc,
		JobType asc
	)
go
