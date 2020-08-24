/*<info serverAlias="DBRMS-bodb_RMS"></info>*/
/*
	Created: 20200824@Percy
	DB: DBRMS-bodb_RMS
	Task: PRMS - Add new table SystemSettings
*/

use bodb_RMS
go

alter table dbo.rmSettings
	alter column VName varchar(100)
go

declare @currentTime varchar(20)
select  @currentTime = convert(varchar(20), getdate(), 120)

insert into dbo.rmSettings (VName, VValue)
select 'SmallOddsLeagueAlert_LastTransDate', @currentTime
union all
select 'SmallOddsAlert_LastTransDate', @currentTime
go