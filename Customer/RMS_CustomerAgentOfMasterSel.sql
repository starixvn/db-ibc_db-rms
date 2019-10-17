
/*<info serverAlias="DBACC-bodb02" executers="bodbRMSNet" viewers="" isFunction="0" isNested="0"></info>*/

CREATE PROCEDURE dbo.RMS_CustomerAgentOfMasterSel @custid INT = 0
AS

/*
Created: Jacob
Date: 2019-10-21
Task: Get all agent of a master
DB: DBACC/bodb02
		
Revisions:
- 20191026@Jacob: Winloss by master RedmineID: [#122137]		
Parameter's Explanation:
    @custid: Id of a master
*/

     SET NOCOUNT ON;
     SELECT DISTINCT 
            custid
     FROM Customer WITH(NOLOCK)
     WHERE mrecommend = @custid
           AND roleid = 2;
	GO