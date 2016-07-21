USE [bodb_RMS]
GO

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
  INTO [rmSumWinloss_backup]
  FROM [dbo].[rmSumWinloss]
GO


