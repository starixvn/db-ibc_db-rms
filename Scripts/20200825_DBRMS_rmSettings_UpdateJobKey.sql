/*<info serverAlias="DBRMS-bodb_RMS"></info>*/

/*
	Created: 20200825@Percy
	DB: DBRMS-bodb_RMS
	Task: Update setting for new job
*/

use bodb_RMS
go

update dbo.rmSettings with (rowlock)
set VValue = '2020-08-25'
where VName in ('SmallOddsLeagueAlert_LastTransDate', 'SmallOddsAlert_LastTransDate')
go