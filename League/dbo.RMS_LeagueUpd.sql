
/*<info serverAlias="DBRMS-bodb_RMS" executers="bodbRMSNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[RMS_LeagueUpd] @LeagueId INT, 
                                      @GroupId  INT, 
                                      @AdminID  INT, 
                                      @IP       VARCHAR(50), 
                                      @ErrCode  INT          = 0 OUTPUT, 
                                      @ErrMsg   VARCHAR(500) = '' OUTPUT
AS

/*
Created: Jacob
Date: 2020-01-20
Task: League Management
DB: DBRMS/bodb_RMS
		
Revisions:

- 20200120@Jacob: League Management #127381

Parameter's Explanation:
*/

     SET NOCOUNT ON;
     DECLARE @startRun DATETIME, @endRun DATETIME, @duration INT;
     SET @startRun = GETDATE();
     DECLARE @old_GroupId INT;
     SELECT @old_GroupId = GroupId
     FROM rmLeague WITH(NOLOCK)
     WHERE LeagueId = @LeagueId;
     IF @@ROWCOUNT = 0
        OR @old_GroupId = @GroupId
         RETURN;
     UPDATE rmLeague WITH(UPDLOCK, ROWLOCK)
       SET 
           GroupId = @GroupId
     WHERE LeagueId = @LeagueId;
     DECLARE @LogData VARCHAR(4000), @LogData_Old VARCHAR(4000);
     SELECT @LogData = '<RMS_LeagueUpd LeagueId="' + COALESCE(CAST(@LeagueId AS VARCHAR(10)), SPACE(1)) + '" ' + 'GroupId="' + COALESCE(CAST(@GroupId AS VARCHAR(10)), SPACE(1)) + '" />';
     SELECT @LogData_Old = '<RMS_LeagueUpd LeagueId="' + COALESCE(CAST(@LeagueId AS VARCHAR(10)), SPACE(1)) + '" ' + 'GroupId="' + COALESCE(CAST(@old_GroupId AS VARCHAR(10)), SPACE(1)) + '" />';
     SET @endRun = GETDATE();
     SET @duration = DATEDIFF(MILLISECOND, @startRun, @endRun);
     EXEC DBLOG.bodb_CustomerLog.[dbo].[RMS_WriteLog_UserLog_RunSP] 
          @Userid = @Adminid, 
          @ActionID = 10501, 
          @TrackingValue = @LogData, 
          @TrackingValue2 = @LogData_Old, 
          @Duration = @duration;
GO