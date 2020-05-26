 SET IDENTITY_INSERT [rmFunction] ON
GO

INSERT INTO [bodb_RMS].[dbo].[rmFunction]( FuncID,
			[FuncName]
           ,[FuncDesc]
           ,[FuncKey]
           ,[ParentID]
           ,[ParentName]
           ,[CreatedDate]
           ,[ModifiedDate]
           ,[Creator]
           ,[DisplayOrder])
SELECT 1,'Administration','Administration','Administration',0,'None',current_timestamp,current_timestamp,5838421,10--dbaAdmin
UNION ALL
SELECT 2,'Manage Group','Manage Group','ManageGroup',1,'Administration',current_timestamp,current_timestamp,5838421,10
UNION ALL
SELECT 3,'Manage User','Manage User','ManageUser',1,'Administration',current_timestamp,current_timestamp,5838421,20
UNION ALL
SELECT 4,'Manage Function','Manage Function','ManageFunction',1,'Administration',current_timestamp,current_timestamp,5838421,30
UNION ALL
SELECT 5,'Manage Menu','Manage Menu','ManageMenu',1,'Administration',current_timestamp,current_timestamp,5838421,40
UNION ALL
SELECT 6,'Monitoring','Monitoring','Monitoring',0,'None',	current_timestamp,current_timestamp,5838421,100
UNION ALL
SELECT 7,'Top Selection','Top Selection','TopSelection',6,'Monitoring',current_timestamp,current_timestamp,5838421,10

SET IDENTITY_INSERT [rmFunction] OFF
GO

SET IDENTITY_INSERT rmMenu ON
GO
INSERT INTO [bodb_RMS].[dbo].[rmMenu]([MenuID]
		   ,[MenuName]
           ,[MenuDesc]
           ,[Url]
           ,[FuncID]
           ,[ParentID]
           ,[ParentName]
           ,[CreatedDate]
           ,[ModifiedDate]
           ,[DisplayOrder]
           ,[Creator]
           ,[enabled])
SELECT 1,'Administration','Administration',NULL,1,0,'None',current_timestamp,current_timestamp,10,5838421,1
UNION ALL
SELECT 2,'Manage Group','Manage Group','~/ManageGroup/GroupList',2,1,'Administration',current_timestamp,current_timestamp,10,5838421,1
UNION ALL
SELECT 3,'Manage User','Manage User','~/ManageUser/UserList',3,1,'Administration',current_timestamp,current_timestamp,20,5838421,1
UNION ALL
SELECT 4,'Manage Function','Manage Function','~/ManageFunction/FunctionList',4,1,'Administration',current_timestamp,current_timestamp,30,5838421,1
UNION ALL
SELECT 5,'Manage Menu','Manage Menu','~/ManageMenu/MenuList',5,1,'Administration',current_timestamp,current_timestamp,40,5838421,1
UNION ALL
SELECT 6,'Monitoring','Monitoring',NULL,6,0,'None',current_timestamp,current_timestamp,40,5838421,1
UNION ALL
SELECT 7,'Top Selection','Top Selection','~/Monitoring/TopSelection',7,6,'Monitoring',current_timestamp,current_timestamp,10,5838421,1

SET IDENTITY_INSERT rmMenu OFF
GO

--create group IT
SET IDENTITY_INSERT rmGroup ON
GO

INSERT INTO [bodb_RMS].[dbo].[rmGroup]
           ( [GroupID]
		   ,[GroupName]
           ,[Description]
           ,[CreatedDate]
           ,[Creator])
SELECT 1,'IT','IT',current_timestamp,5838421

SET IDENTITY_INSERT rmGroup ON
GO
--Add users IT group

DECLARE @user TABLE (userid int)

INSERT INTO @user (userid)
SELECT custid
FROM bodb02.dbo.custinfo WITH(NOLOCK)
WHERE username IN ('dbaJamie','dbaJohnson','pgmTerry','pgmKaka','pgmAnn','pgmKiwi','pgmLee')

INSERT INTO [bodb_RMS].[dbo].[rmUserInfo]
           ([UserID]
           ,[GroupID]
           ,[enabled]
           ,[creator]
           ,[CreatedDate])
SELECT userid, 1, 1, 8, current_timestamp
FROM @user

-- Grant permission
INSERT INTO [bodb_RMS].[dbo].[rmUserPolicy]
           ([UserID]
           ,[FuncID]
           ,[Policy])
SELECT userid, FuncID, 2
FROM @user, rmFunction