USE [bodb_RMS];
GO

/*
	Created: Franklin
	Date: 2020-02-26
	Task: Notify/Alert by Winning Amount
	DB: DBRMS/bodb_RMS


Revisions:
- 20200226@Franklin: Notify/Alert by Winning Amount #129275
*/

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
SET ANSI_PADDING ON;
GO
CREATE TABLE [dbo].[rmLastTicketAlert]
([TransId]     [BIGINT] NOT NULL, 
 [AlertTime]   [DATETIME] NOT NULL, 
 [AlertAmount] [MONEY] NOT NULL, 
 [ParlayType]  [VARCHAR](30) NOT NULL, 
 CONSTRAINT [PK_rmLastTicketAlert] PRIMARY KEY CLUSTERED([TransId] ASC)
 WITH(PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
)
ON [PRIMARY];
GO
SET ANSI_PADDING OFF;
GO
ALTER TABLE [dbo].[rmLastTicketAlert]
ADD CONSTRAINT [DF_rmLastTicketAlert_TransId] DEFAULT((0)) FOR [TransId];
GO
ALTER TABLE [dbo].[rmLastTicketAlert]
ADD CONSTRAINT [DF_rmLastTicketAlert_AlertTime] DEFAULT('2000-01-01') FOR [AlertTime];
GO
ALTER TABLE [dbo].[rmLastTicketAlert]
ADD CONSTRAINT [DF_rmLastTicketAlert_AlertAmount] DEFAULT((0)) FOR [AlertAmount];
GO
ALTER TABLE [dbo].[rmLastTicketAlert]
ADD CONSTRAINT [DF_rmLastTicketAlert_ParlayType] DEFAULT('') FOR [ParlayType];
GO