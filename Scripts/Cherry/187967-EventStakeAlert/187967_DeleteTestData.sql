/*<info serverAlias="DBRMS-bodb_RMS" executers="" isFunction="0" isNested="0"></info>*/
-- https://nexdev.net/issues/187967

USE [bodb_RMS]
GO

DELETE FROM dbo.rmLastTicketAlert WHERE JobType = 5
GO