 use bodb_CustomerLog
GO

--actionid = 10000 RMS_GroupInfoIns
--<RMS_GroupInfoIns> GroupName="aaaaaa" Description=" " IP="10.19.10.61" </RMS_GroupInfoIns>
--<RMS_GroupInfoIns GroupName="aaaaaa" Description=" " IP="10.19.10.61" />
UPDATE rmUserLog_UserControl WITH(UPDLOCK,ROWLOCK)
SET doing = replace(Doing,'<RMS_GroupInfoIns>','<RMS_GroupInfoIns')  
where ActionID = 10000

UPDATE rmUserLog_UserControl WITH(UPDLOCK,ROWLOCK)
SET doing = replace(Doing,'</RMS_GroupInfoIns>','/>')  
where ActionID = 10000

--actionid = 10001 RMS_GroupInfoUpd
--<RMS_GroupInfoUpd> GroupNameOld="test2" GroupNameNew="test2" DescriptionOld="test2" DescriptionNew="test2dsd" IP="10.19.10.66" </RMS_GroupInfoUpd>
--<RMS_GroupInfoUpd GroupNameOld="test2" GroupNameNew="test2" DescriptionOld="test2" DescriptionNew="test2dsd" IP="10.19.10.66" />
UPDATE rmUserLog_UserControl WITH(UPDLOCK,ROWLOCK)
SET doing = replace(Doing,'<RMS_GroupInfoUpd>','<RMS_GroupInfoUpd')  
where ActionID = 10001

UPDATE rmUserLog_UserControl WITH(UPDLOCK,ROWLOCK)
SET doing = replace(Doing,'</RMS_GroupInfoUpd>','/>')  
where ActionID = 10001

--actionid = 10002 RMS_GroupPolicyUpd
--<RMS_GroupPolicyUpd> GroupPolicy="15,0;18,0;20,0;1,0;2,0;3,0;19,0;4,0;6,0;5,0;11,0;12,0;13,0;14,0;16,0;17,0" IP="10.19.10.61" </RMS_GroupPolicyUpd>
--<RMS_GroupPolicyUpd GroupPolicy="15,0;18,0;20,0;1,0;2,0;3,0;19,0;4,0;6,0;5,0;11,0;12,0;13,0;14,0;16,0;17,0" IP="10.19.10.61" />
UPDATE rmUserLog_UserControl WITH(UPDLOCK,ROWLOCK)
SET doing = replace(Doing,'<RMS_GroupPolicyUpd>','<RMS_GroupPolicyUpd')  
where ActionID = 10002

UPDATE rmUserLog_UserControl WITH(UPDLOCK,ROWLOCK)
SET doing = replace(Doing,'</RMS_GroupPolicyUpd>','/>')  
where ActionID = 10002

--actionid = 10003 RMS_UserInfoAddNew
--<RMS_UserInfoAddNew> UserName="ABC" FirstName="" LastName="" GroupID="121" IP="10.19.10.112" </RMS_UserInfoAddNew>
--<RMS_UserInfoAddNew UserName="ABC" FirstName="" LastName="" GroupID="121" IP="10.19.10.112" />
UPDATE rmUserLog_UserControl WITH(UPDLOCK,ROWLOCK)
SET doing = replace(Doing,'<RMS_UserInfoAddNew>','<RMS_UserInfoAddNew')  
where ActionID = 10003

UPDATE rmUserLog_UserControl WITH(UPDLOCK,ROWLOCK)
SET doing = replace(Doing,'</RMS_UserInfoAddNew>','/>')  
where ActionID = 10003

--actionid = 10004 RMS_UserInfoAddExisting
--<RMS_UserInfoAddExisting> UserName="pgmjohn" GroupID="1" IP="10.19.10.112" </RMS_UserInfoAddExisting>
--<RMS_UserInfoAddExisting UserName="pgmjohn" GroupID="1" IP="10.19.10.112" />
UPDATE rmUserLog_UserControl WITH(UPDLOCK,ROWLOCK)
SET doing = replace(Doing,'<RMS_UserInfoAddExisting>','<RMS_UserInfoAddExisting')  
where ActionID = 10004

UPDATE rmUserLog_UserControl WITH(UPDLOCK,ROWLOCK)
SET doing = replace(Doing,'</RMS_UserInfoAddExisting>','/>')  
where ActionID = 10004

--actionid = 10005  RMS_UserInfoUpdUserGroup
--<RMS_UserInfoUpdUserGroup> GroupIDOld="1" GroupIDNew="84" IP="10.19.10.61" </RMS_UserInfoUpdUserGroup>
--<RMS_UserInfoUpdUserGroup GroupIDOld="1" GroupIDNew="84" IP="10.19.10.61" />
UPDATE rmUserLog_UserControl WITH(UPDLOCK,ROWLOCK)
SET doing = replace(Doing,'<RMS_UserInfoUpdUserGroup>','<RMS_UserInfoUpdUserGroup')  
where ActionID = 10005

UPDATE rmUserLog_UserControl WITH(UPDLOCK,ROWLOCK)
SET doing = replace(Doing,'</RMS_UserInfoUpdUserGroup>','/>')  
where ActionID = 10005

--actionid = 10006 RMS_UserPolicyUpd
--<RMS_UserPolicyUpd> UserPolicy="15,2;22,2;18,0;20,0;1,2;2,2;3,2;19,2;4,2;6,2;5,2;11,0;12,0;13,0;21,0;14,0;16,0;17,0" IP="10.19.10.92" </RMS_UserPolicyUpd>
--<RMS_UserPolicyUpd UserPolicy="15,2;22,2;18,0;20,0;1,2;2,2;3,2;19,2;4,2;6,2;5,2;11,0;12,0;13,0;21,0;14,0;16,0;17,0" IP="10.19.10.92" />
UPDATE rmUserLog_UserControl WITH(UPDLOCK,ROWLOCK)
SET doing = replace(Doing,'<RMS_UserPolicyUpd>','<RMS_UserPolicyUpd')  
where ActionID = 10006

UPDATE rmUserLog_UserControl WITH(UPDLOCK,ROWLOCK)
SET doing = replace(Doing,'</RMS_UserPolicyUpd>','/>')  
where ActionID = 10006

--actionid = 10007 RMS_UserInfoUpdAll
--<RMS_UserInfoUpdAll> FirstNameOld="" FirstNameNew="aa" LastNameOld="" LastNameNew="" IP="10.19.10.61" </RMS_UserInfoUpdAll>
--<RMS_UserInfoUpdAll FirstNameOld="" FirstNameNew="aa" LastNameOld="" LastNameNew="" IP="10.19.10.61" />
UPDATE rmUserLog_UserControl WITH(UPDLOCK,ROWLOCK)
SET doing = replace(Doing,'<RMS_UserInfoUpdAll>','<RMS_UserInfoUpdAll')  
where ActionID = 10007

UPDATE rmUserLog_UserControl WITH(UPDLOCK,ROWLOCK)
SET doing = replace(Doing,'</RMS_UserInfoUpdAll>','/>')  
where ActionID = 10007

--actionid = 10100 RMS_FunctionIns
--<RMS_FunctionIns> FuncName="Monitor" FuncDesc="Monitor" FuncKey="Monitor" ParentID="0" ParentName="None" DisplayOrder="50" IP="10.19.10.66" </RMS_FunctionIns>
--<RMS_FunctionIns FuncName="Monitor" FuncDesc="Monitor" FuncKey="Monitor" ParentID="0" ParentName="None" DisplayOrder="50" IP="10.19.10.66" />
UPDATE rmUserLog_UserControl WITH(UPDLOCK,ROWLOCK)
SET doing = replace(Doing,'<RMS_FunctionIns>','<RMS_FunctionIns')  
where ActionID = 10100

UPDATE rmUserLog_UserControl WITH(UPDLOCK,ROWLOCK)
SET doing = replace(Doing,'</RMS_FunctionIns>','/>')  
where ActionID = 10100

--actionid = 10101 RMS_FunctionUpd
--<RMS_FunctionUpd> FuncNameOld="Administration" FuncNameNew="Administration" FuncDescNew="Administration" FuncDescOld="Administration" ParentNameOld="None" ParentNameNew="None" DisplayOrderOld="10" DisplayOrderNew="1" IP="10.19.10.66" </RMS_FunctionUpd>
--<RMS_FunctionUpd FuncNameOld="Administration" FuncNameNew="Administration" FuncDescNew="Administration" FuncDescOld="Administration" ParentNameOld="None" ParentNameNew="None" DisplayOrderOld="10" DisplayOrderNew="1" IP="10.19.10.66" />
UPDATE rmUserLog_UserControl WITH(UPDLOCK,ROWLOCK)
SET doing = replace(Doing,'<RMS_FunctionUpd>','<RMS_FunctionUpd')  
where ActionID = 10101

UPDATE rmUserLog_UserControl WITH(UPDLOCK,ROWLOCK)
SET doing = replace(Doing,'</RMS_FunctionUpd>','/>')  
where ActionID = 10101

--actionid = 10300  RMS_UserInfoUpdStatus
--<RMS_UserInfoUpdStatus> CustID="6913413" enabled="1" IP="10.19.10.104" </RMS_UserInfoUpdStatus>
--<RMS_UserInfoUpdStatus CustID="6913413" enabled="1" IP="10.19.10.104" />
UPDATE rmUserLog_RunSP WITH(UPDLOCK,ROWLOCK)
SET TrackingValue = replace(TrackingValue,'<RMS_UserInfoUpdStatus>','<RMS_UserInfoUpdStatus')  
where ActionID = 10300

UPDATE rmUserLog_RunSP WITH(UPDLOCK,ROWLOCK)
SET TrackingValue = replace(TrackingValue,'</RMS_UserInfoUpdStatus>','/>')  
where ActionID = 10300

--actionid = 10301 RMS_UserInfoUpdUserpwd
--<RMS_UserInfoUpdUserpwd> CustID="6913387" IP="10.19.10.104" </RMS_UserInfoUpdUserpwd>
--<RMS_UserInfoUpdUserpwd CustID="6913387" IP="10.19.10.104" />
UPDATE rmUserLog_RunSP WITH(UPDLOCK,ROWLOCK)
SET TrackingValue = replace(TrackingValue,'<RMS_UserInfoUpdUserpwd>','<RMS_UserInfoUpdUserpwd')  
where ActionID = 10301

UPDATE rmUserLog_RunSP WITH(UPDLOCK,ROWLOCK)
SET TrackingValue = replace(TrackingValue,'</RMS_UserInfoUpdUserpwd>','/>')  
where ActionID = 10301 

--actionid = 10400  RMS_CustomerIns
--<RMS_CustomerIns> UserName="testcs0101000" level="0" IP="10.19.10.112" </RMS_CustomerIns>
--<RMS_CustomerIns UserName="testcs0101001" level="9" IP="10.19.10.61" />
UPDATE rmUserLog_RunSP WITH(UPDLOCK,ROWLOCK)
SET TrackingValue = replace(TrackingValue,'<RMS_CustomerIns>','<RMS_CustomerIns')  
where ActionID = 10400

UPDATE rmUserLog_RunSP WITH(UPDLOCK,ROWLOCK)
SET TrackingValue = replace(TrackingValue,'</RMS_CustomerIns>','/>')  
where ActionID = 10400 

--actionid = 10401 RMS_CustomerUpd
--<RMS_CustomerUpd> custid="1245387"level="0"</RMS_CustomerUpd>
--<RMS_CustomerUpd custid="1245387" level="0" />
UPDATE rmUserLog_RunSP WITH(UPDLOCK,ROWLOCK)
SET TrackingValue = replace(TrackingValue,'<RMS_CustomerUpd>','<RMS_CustomerUpd'),
	TrackingValue2 = replace(TrackingValue2,'<RMS_CustomerUpd>','<RMS_CustomerUpd')
where ActionID = 10401

UPDATE rmUserLog_RunSP WITH(UPDLOCK,ROWLOCK)
SET TrackingValue = replace(TrackingValue,'</RMS_CustomerUpd>',' />'),
	TrackingValue2 = replace(TrackingValue2,'</RMS_CustomerUpd>',' />')   
where ActionID = 10401

UPDATE rmUserLog_RunSP WITH(UPDLOCK,ROWLOCK)
SET TrackingValue = replace(TrackingValue,'"level','" level'),
	TrackingValue2 = replace(TrackingValue2,'"level','" level')   
where ActionID = 10401