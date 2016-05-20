USE [bodb_RMS]
GO

/****** Object:  Table [dbo].[rmSumWinloss]    Script Date: 5/25/2016 12:54:40 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

SET ANSI_PADDING ON
GO

TRUNCATE TABLE rmSumWinloss
GO
INSERT INTO [rmSumWinloss]
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

SELECT [winlostdate]
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
     
  FROM [dbo].[rmSumWinloss_backup]
GO


