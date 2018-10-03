/*
		Created: Jacob
		Date: 2018-09-27
		Task: Apply Extra PT and Super Comm to Report.  RedmineID: #100951
		DB: DBRMS/bodb_RMS
		
		Revisions:
			- 20180927@Jacob: Apply Extra PT and Super Comm to Report.  RedmineID: #100951 		
		Parameter's Explanation:
*/

USE [bodb_RMS]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE TABLE [dbo].[rmSumWinlossExtraPT](
	[winlostdate] [smalldatetime] NOT NULL,
	[custid] [int] NOT NULL,
	[sporttype] [smallint] NULL,
	[statusid] [tinyint] NOT NULL,
	[combo] [tinyint] NOT NULL,
	[stake] [money] NULL,
	[winlost] [money] NULL,
	[comm] [money] NULL,
	[scomm] [money] NULL	
) ON [rmSumWinloss]
GO



CREATE CLUSTERED INDEX [CIX_rmSumWinlossExtraPT] ON [dbo].[rmSumWinlossExtraPT]
(
	[custid] ASC,
	[winlostdate] ASC,
	[sporttype] ASC,
	[statusid] ASC,
	[combo] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [rmSumWinloss]
GO



CREATE TABLE [dbo].[rmSumWinlossExtraPT_Old](
	[winlostdate] [smalldatetime] NOT NULL,
	[custid] [int] NOT NULL,
	[sporttype] [smallint] NULL,
	[statusid] [tinyint] NOT NULL,
	[combo] [tinyint] NOT NULL,	
	[stake] [money] NULL,
	[winlost] [money] NULL,
	[comm] [money] NULL,	
	[scomm] [money] NULL
) ON [rmSumWinlossOld]
GO


CREATE CLUSTERED INDEX [CIX_rmSumWinlossExtraPT_OLD] ON [dbo].[rmSumWinlossExtraPT_Old]
(
	[custid] ASC,
	[winlostdate] ASC,
	[sporttype] ASC,
	[statusid] ASC,
	[combo] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [rmSumWinlossOld]
GO


