USE [bodb_RMS]
GO

/****** Object:  Table [dbo].[rmSumWinloss_Old]    Script Date: 5/25/2016 12:56:47 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

SET ANSI_PADDING ON
GO
DELETE FROM rmSumWinloss_Old WHERE winlostdate>='2016-05-01'
INSERT INTO rmSumWinloss_Old
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
     
  FROM [dbo].[rmSumWinloss_Old_backup]
  WHERE winlostdate>='2016-05-01'

