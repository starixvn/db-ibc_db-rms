/*<info serverAlias="DBRMS-bodb_RMS" executers="" isFunction="0" isNested="0"></info>*/
-- https://nexdev.net/issues/185896

USE [bodb_RMS]
GO

alter table rmBettrans 
alter column  betfrom nvarchar(4) null

alter table rmBettrans_Old 
alter column  betfrom nvarchar(4) null