USE bodb_RMS
GO
SET NOCOUNT ON

ALTER TABLE [dbo].[rmBettrans]
ADD TotalBet INT

ALTER TABLE [dbo].[rmSumWinloss]
ADD [ParlayType] TINYINT NULL
GO
--
ALTER TABLE [dbo].[rmSumWinloss_OLD]
ADD [ParlayType] TINYINT NULL
GO

--drop index
DROP INDEX CIX_rmSumWinloss   
    ON rmSumWinloss
GO 

ALTER TABLE [dbo].[rmSumWinloss]
ALTER COLUMN Sporttype SMALLINT NULL
GO
--recreate index
CREATE CLUSTERED INDEX [CIX_rmSumWinloss] ON [dbo].[rmSumWinloss] 
(
	[custid] ASC,
	[winlostdate] ASC,
	[sporttype] ASC,
	[statusid] ASC,
	[combo] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [rmSumWinloss]
GO

--drop index
DROP INDEX CIX_rmSumWinloss_OLD  
    ON rmSumWinloss_OLD
GO 

ALTER TABLE [dbo].[rmSumWinloss_OLD]
ALTER COLUMN Sporttype SMALLINT NULL
GO

--recreate index
CREATE CLUSTERED INDEX [CIX_rmSumWinloss_OLD] ON [dbo].[rmSumWinloss_OLD] 
(
	[custid] ASC,
	[winlostdate] ASC,
	[sporttype] ASC,
	[statusid] ASC,
	[combo] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [rmSumWinlossOLD]
GO

USE bodb02;  
GRANT SELECT ON Sports TO bodbRMSNet;  
GO  
