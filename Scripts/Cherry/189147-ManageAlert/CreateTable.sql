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
		[Remark] [VARCHAR](500) NOT NULL
) ON [rmDATA]
WITH (DATA_COMPRESSION = PAGE)
GO

CREATE UNIQUE CLUSTERED INDEX [CIX_AlertTypeID] ON [dbo].[rmAlertType]
(
	AlertTypeID ASC
)WITH (DATA_COMPRESSION = PAGE)
 ON [rmDATA]
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

CREATE UNIQUE CLUSTERED INDEX [CIX_ActionID] ON [dbo].[rmAlertAction]
(
	ActionID ASC
)WITH (DATA_COMPRESSION = PAGE)
 ON [rmDATA]
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
		[LogTime] [DATETIME] NOT NULL,
		[AlertID] [BIGINT] NOT NULL,
		[UserID] [INT] NOT NULL,
		[ActionID] [SMALLINT] NOT NULL
) ON [rmAlertLog]
WITH (DATA_COMPRESSION = PAGE)
GO

CREATE CLUSTERED INDEX [CIX_AlertID] ON [dbo].[rmAlertLog]
(
	AlertID ASC
)WITH (DATA_COMPRESSION = PAGE)
 ON [rmAlertLog]
GO

CREATE NONCLUSTERED INDEX [IX_LogTime] ON [dbo].[rmAlertLog]
(
	LogTime ASC
)WITH (DATA_COMPRESSION = PAGE)
 ON [rmAlertLog]
GO

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
		[AlertTime] [DATETIME] NOT NULL,
		[TransID] [BIGINT] NOT NULL,
		[CustID] [INT] NOT NULL,
		[AlertType] [SMALLINT] NOT NULL,
		[CheckBy] [INT],
		[AlertAction] [SMALLINT] DEFAULT(0),
		[TransInfo] VARBINARY(MAX),
		[IsTest] BIT NOT NULL
) ON [rmAlert]
WITH (DATA_COMPRESSION = PAGE)
GO

CREATE NONCLUSTERED INDEX [IX_AlertID] ON [dbo].[rmAlert]
(
	AlertID ASC
)WITH (DATA_COMPRESSION = PAGE)
 ON [rmAlert]
GO

CREATE CLUSTERED INDEX [CIX_AlertTime] ON [dbo].[rmAlert]
(
	AlertTime ASC
)WITH (DATA_COMPRESSION = PAGE)
 ON [rmAlert]
GO

ALTER DATABASE bodb_RMS
ADD FILEGROUP rmAlertDetail
GO

ALTER DATABASE bodb_RMS 
ADD FILE 
(
	NAME = rmAlertDetail,
	FILENAME = 'E:\IBC_DB\bodb_RMS\rmAlertDetail\rmAlertDetail.ndf',
	SIZE = 5MB,
	MAXSIZE = UNLIMITED,
	FILEGROWTH = 32MB
)
TO FILEGROUP rmAlertDetail
GO

IF OBJECT_ID('bodb_RMS.dbo.rmAlertDetail') IS NOT NULL
BEGIN
	DROP TABLE dbo.rmAlertDetail
END

CREATE TABLE [dbo].rmAlertDetail(
		[AlertID] [BIGINT] NOT NULL,
		[RefType] [SMALLINT] NOT NULL,
		[RefValInt] [BIGINT]  NULL,
		[RefValStr] VARCHAR(1000)  NULL
) ON [rmAlertDetail]
WITH (DATA_COMPRESSION = PAGE)
GO

CREATE CLUSTERED INDEX [CX_AlertID] ON [dbo].[rmAlertDetail]
(
	AlertID ASC,
	RefType ASC
)WITH (DATA_COMPRESSION = PAGE)
 ON [rmAlertDetail]
GO

USE bodb02
GO

GRANT SELECT ON bodb02.dbo.strSplit TO bodbRMSNet
GO

GRANT EXECUTE ON bodb02.dbo.f_CheckSPVersion TO bodbRMSNet
GO

--GRANT SELECT,INSERT, UPDATE ON dbo.rmAlertLog TO bodbRMSNet
--GO

--GRANT SELECT,INSERT, UPDATE ON dbo.rmAlert TO bodbRMSNet
--GO

--GRANT SELECT,INSERT, UPDATE ON dbo.rmAlertDetail TO bodbRMSNet
--GO

--GRANT SELECT ON dbo.rmAlertType TO bodbRMSNet
--GO

--GRANT SELECT ON dbo.rmAlertAction TO bodbRMSNet
--GO