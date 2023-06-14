/*<info serverAlias="DBRMS-bodb_RMS" isFunction="0" isNested="0"></info>*/
/*
Created by Cherry@20230620
Run at DBRMS@bodb_RMS 
Task: Manage Alert Letstalk Function (#189147)
*/
USE bodb_RMS
GO

IF OBJECT_ID('bodb_RMS.dbo.rmAlertType') IS NOT NULL
BEGIN
	DROP TABLE dbo.rmAlertType
END

CREATE TABLE [dbo].rmAlertType(
		[AlertTypeID] [SMALLINT] NOT NULL,
		[AlertTypeName] [VARCHAR](500) NOT NULL,
		[Remark] [VARCHAR](500)
) ON [rmDATA]
WITH (DATA_COMPRESSION = PAGE)
GO

ALTER TABLE dbo.rmAlertType
	ADD CONSTRAINT PK_rmAlertType PRIMARY KEY
	(
		AlertTypeID ASC
	)
GO

IF OBJECT_ID('bodb_RMS.dbo.rmAlertAction') IS NOT NULL
BEGIN
	DROP TABLE dbo.rmAlertAction
END

CREATE TABLE [dbo].rmAlertAction(
		[ActionID] [SMALLINT] NOT NULL,
		[ActionName] [VARCHAR](500) NOT NULL
) ON [rmDATA]
WITH (DATA_COMPRESSION = PAGE)
GO

ALTER TABLE dbo.rmAlertAction
	ADD CONSTRAINT PK_rmAlertAction PRIMARY KEY
	(
		ActionID ASC
	)
GO

ALTER DATABASE bodb_RMS
ADD FILEGROUP rmAlertLog
GO

ALTER DATABASE bodb_RMS 
ADD FILE 
(
	NAME = rmAlertLog,
	FILENAME = 'E:\IBC_DB\bodb_RMS\rmAlertLog\rmAlertLog.ndf',
	SIZE = 5MB,
	MAXSIZE = UNLIMITED,
	FILEGROWTH = 32MB
)
TO FILEGROUP rmAlertLog
GO

IF OBJECT_ID('bodb_RMS.dbo.rmAlertLog') IS NOT NULL
BEGIN
	DROP TABLE dbo.rmAlertLog
END

CREATE TABLE [dbo].rmAlertLog(
		[LogID] [BIGINT] IDENTITY(1,1) NOT NULL,
		[LogTime] [DATETIME],
		[AlertID] [BIGINT],
		[UserID] [INT],
		[ActionID] [SMALLINT]
) ON [rmAlertLog]
WITH (DATA_COMPRESSION = PAGE)
GO

ALTER TABLE dbo.rmAlertLog
	ADD CONSTRAINT PK_rmAlertLog PRIMARY KEY
	(
		LogID ASC
	)
GO

CREATE NONCLUSTERED INDEX [CIX_rmAlertLog] ON [dbo].[rmAlertLog]
(
	LogTime ASC
)WITH (DATA_COMPRESSION = PAGE)
 ON [rmAlertLog]
GO

CREATE NONCLUSTERED INDEX [IX_AlertID] ON [dbo].[rmAlertLog]
(
	AlertID ASC
)WITH (DATA_COMPRESSION = PAGE)
 ON [rmAlertLog]
GO
--------
ALTER DATABASE bodb_RMS
ADD FILEGROUP rmAlert
GO

ALTER DATABASE bodb_RMS 
ADD FILE 
(
	NAME = rmAlert,
	FILENAME = 'E:\IBC_DB\bodb_RMS\rmAlert\rmAlert.ndf',
	SIZE = 5MB,
	MAXSIZE = UNLIMITED,
	FILEGROWTH = 32MB
)
TO FILEGROUP rmAlert
GO

IF OBJECT_ID('bodb_RMS.dbo.rmAlert') IS NOT NULL
BEGIN
	DROP TABLE dbo.rmAlert
END

CREATE TABLE [dbo].rmAlert(
		[AlertID] [BIGINT] IDENTITY(1,1) NOT NULL,
		[AlertTime] [DATETIME],
		[TransID] [BIGINT],
		[CustID] [INT],
		[AlertType] [SMALLINT],
		[CheckBy] [INT],
		[AlertAction] [SMALLINT],
		[Content] NVARCHAR(MAX),
		[IsTest] BIT
) ON [rmAlert]
WITH (DATA_COMPRESSION = PAGE)
GO

ALTER TABLE dbo.rmAlert
	ADD CONSTRAINT PK_rmAlert PRIMARY KEY
	(
		AlertID ASC
	)
GO

CREATE NONCLUSTERED INDEX [CIX_rmAlert] ON [dbo].[rmAlert]
(
	AlertTime ASC
)WITH (DATA_COMPRESSION = PAGE)
 ON [rmAlert]
GO