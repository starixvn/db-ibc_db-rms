/*<info serverAlias="DBRMS-bodb_RMS" isFunction="0" isNested="0"></info>*/
/*
Created by Cherry@20240701
Run at DBRMS@bodb_RMS 
Task: Alert Major Bettype (#202238)
*/
USE bodb_RMS
GO
ALTER DATABASE bodb_RMS
ADD FILEGROUP rmMajorBettypeAlert
GO

ALTER DATABASE bodb_RMS 
ADD FILE 
(
	NAME = rmMajorBettypeAlert,
	FILENAME = 'I:\user_db\bodb_RMS\rmMajorBettypeAlert\rmMajorBettypeAlert.ndf',
	SIZE = 5MB,
	MAXSIZE = UNLIMITED,
	FILEGROWTH = 32MB
)
TO FILEGROUP rmMajorBettypeAlert
GO

IF OBJECT_ID('bodb_RMS.dbo.rmMajorBettypeAlert') IS NOT NULL
BEGIN
	DROP TABLE dbo.rmMajorBettypeAlert
END

CREATE TABLE [dbo].rmMajorBettypeAlert(
		[AlertID] [BIGINT] IDENTITY(1,1) NOT NULL,
		[AlertTime] [DATETIME] NOT NULL,
		[MatchID] [INT] NOT NULL,
		[Bettype] [INT] NOT NULL,
		[Betcheck] [NVARCHAR](50) NULL,
		[AlertType] [SMALLINT] NOT NULL,
		[NumberTime] [INT] NOT NULL,
		[HomeStake] MONEY NOT NULL,
		[AwayStake] MONEY NOT NULL,
		[IsTest] BIT NOT NULL
) ON [rmMajorBettypeAlert]
WITH (DATA_COMPRESSION = PAGE)
GO

CREATE CLUSTERED INDEX [IX_AlertID] ON [dbo].[rmMajorBettypeAlert]
(
	AlertID ASC
)WITH (DATA_COMPRESSION = PAGE)
 ON [rmMajorBettypeAlert]
GO

CREATE NONCLUSTERED INDEX [IX_MatchID] ON [dbo].[rmMajorBettypeAlert]
(
	MatchID ASC,
	Bettype ASC,
	NumberTime ASC
)WITH (DATA_COMPRESSION = PAGE)
 ON [rmMajorBettypeAlert]
GO