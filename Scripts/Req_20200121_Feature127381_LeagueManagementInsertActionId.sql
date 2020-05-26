
/*
		Created: Jacob
		Date: 2020-01-21
		Task: League Management
		DB: DBLOG/bodb_CustomerLog
		
		Revisions:
			- 20200121@Jacob: League Management: #127381
		Parameter's Explanation:
*/
USE [bodb_CustomerLog]
GO

INSERT INTO [dbo].[LogAction]
           ([ActionID]
           ,[ActionTypeID]
           ,[SPName]
           ,[ActionNameEN]
           ,[ActionNameCH]
           ,[ActionNameCS]
           ,[ActionNameJP]
           ,[ActionNameIT]
           ,[ActionNameTH]
           ,[ActionNameKO]
           ,[XsltContent]
           ,[IsInternal]
           ,[ActionNameVI]
           ,[ActionNameCN])
     VALUES
           (10500
           ,NULL
           ,'RMS_LeagueIns'
           ,N'Add new special league'
           ,N'Add new special league'
           ,N'Add new special league'
           ,N'Add new special league'
           ,N'Add new special league'
           ,N'Add new special league'
           ,N'Add new special league'
           ,NULL
           ,0
           ,N'Add new special member'
           ,N'Add new special member')


		   
INSERT INTO [dbo].[LogAction]
           ([ActionID]
           ,[ActionTypeID]
           ,[SPName]
           ,[ActionNameEN]
           ,[ActionNameCH]
           ,[ActionNameCS]
           ,[ActionNameJP]
           ,[ActionNameIT]
           ,[ActionNameTH]
           ,[ActionNameKO]
           ,[XsltContent]
           ,[IsInternal]
           ,[ActionNameVI]
           ,[ActionNameCN])
     VALUES
           (10501
           ,NULL
           ,'RMS_LeagueUpd'
           ,N'Update special league to new group'
           ,N'Update special league to new group'
           ,N'Update special league to new group'
           ,N'Update special league to new group'
           ,N'Update special league to new group'
           ,N'Update special league to new group'
           ,N'Update special league to new group'
           ,NULL
           ,0
           ,N'Update special league to new group'
           ,N'Update special league to new group')
GO

