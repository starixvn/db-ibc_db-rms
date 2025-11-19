/*<info serverAlias="DBRMS-bodb_RMS" isFunction="0" isNested="0"></info>*/
ALTER TABLE bodb_RMS.dbo.rmPotentialWinningAlert
ADD IsHP BIT NOT NULL DEFAULT(0)

ALTER TABLE bodb_RMS.dbo.rmPotentialWinningAlert
DROP CONSTRAINT PK_rmPotentialWinningAlert

ALTER TABLE bodb_RMS.dbo.rmPotentialWinningAlert
ADD CONSTRAINT PK_rmPotentialWinningAlert PRIMARY KEY CLUSTERED 
(
	[IsSMP] ASC,	
	[IsHP] ASC,
	[CustId] ASC,
	[AlertTime] DESC
)






