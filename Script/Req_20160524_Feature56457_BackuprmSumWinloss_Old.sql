USE [bodb_RMS]
GO

/****** Object:  Table [dbo].[rmSumWinloss_Old]    Script Date: 5/25/2016 12:56:47 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

SET ANSI_PADDING ON
GO

CREATE TABLE [dbo].[rmSumWinloss_Old_backup](
	[winlostdate] [smalldatetime] NOT NULL,
	[custid] [int] NOT NULL,
	[sporttype] [smallint] NOT NULL,
	[statusid] [tinyint] NOT NULL,
	[combo] [tinyint] NOT NULL,
	[username] [varchar](30) NOT NULL,
	[currency] [tinyint] NULL,
	[stake] [money] NULL,
	[winlost] [money] NULL,
	[company_stake] [money] NULL,
	[company_winlost] [money] NULL,
	[actualrate] [float] NULL,
	[odds] [smallmoney] NULL,
	[betcount] [int] NULL,
	[recommend] [int] NULL
	
) ON [rmSumWinlossOld]

GO


INSERT INTO rmSumWinloss_Old_backup
(
 [winlostdate]
      ,[custid]
      ,[sporttype]
      ,[statusid]
      ,[combo]
      ,[username]
      ,[currency]
      ,[stake]
      ,[winlost]
      ,[company_stake]
      ,[company_winlost]
      ,[actualrate]
      ,[odds]
      ,[betcount]
      ,[recommend]
      
)
SELECT 
		[winlostdate]
      ,[custid]
      ,[sporttype]
      ,[statusid]
      ,[combo]
      ,[username]
      ,[currency]
      ,[stake]
      ,[winlost]
      ,[company_stake]
      ,[company_winlost]
      ,[actualrate]
      ,[odds]
      ,[betcount]
      ,[recommend]
      
  FROM [dbo].[rmSumWinloss_Old]
  WHERE winlostdate>='2016-05-01'

