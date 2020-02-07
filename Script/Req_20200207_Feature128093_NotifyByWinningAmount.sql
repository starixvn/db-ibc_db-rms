USE [bodb_RMS]
GO

/*
	Created: Jacob
	Date: 2020-02-07
	Task: Notify/Alert by Winning Amount
	DB: DBRMS/bodb_RMS
Revisions:
- 20200207@Jacob: Notify/Alert by Winning Amount #128093
*/

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE TABLE dbo.rmPotentialWinningAlert
(
	CustId		INT			NOT NULL,
	AlertTime	DATETIME	NOT NULL,
	AlertAmount MONEY		NOT NULL,
	IsSMP	BIT		NOT NULL,
	CONSTRAINT [PK_rmPotentialWinningAlert] PRIMARY KEY
	(
		IsSMP	ASC,
		CustId		ASC,
		AlertTime	DESC
	) ON rmDATA
) ON rmDATA

ALTER TABLE [dbo].[rmPotentialWinningAlert] ADD  CONSTRAINT [DF_rmPotentialWinningAlert_CustId]  DEFAULT ((0)) FOR [CustId]
GO

ALTER TABLE [dbo].[rmPotentialWinningAlert] ADD  CONSTRAINT [DF_rmPotentialWinningAlert_AlertTime]  DEFAULT ('2000-01-01') FOR [AlertTime]
GO

ALTER TABLE [dbo].[rmPotentialWinningAlert] ADD  CONSTRAINT [DF_rmPotentialWinningAlert_AlertAmount]  DEFAULT ((0)) FOR [AlertAmount]
GO

ALTER TABLE [dbo].[rmPotentialWinningAlert] ADD  CONSTRAINT [DF_rmPotentialWinningAlert_ParlayType]  DEFAULT ((0)) FOR [IsSMP]
GO


