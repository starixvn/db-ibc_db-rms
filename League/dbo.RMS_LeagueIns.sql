
/*<info serverAlias="DBRMS-bodb_RMS" executers="bodbRMSNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[RMS_LeagueIns] @leaguename NVARCHAR(500), 
                                      @GroupId    INT, 
                                      @AdminID    INT, 
                                      @IP         VARCHAR(50), 
                                      @ErrCode    INT           = 0 OUTPUT, 
                                      @ErrMsg     VARCHAR(500)  = '' OUTPUT
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
     DECLARE @LeagueId INT;
     SELECT @LeagueId = l.leagueid
     FROM bodb02.dbo.League l WITH(NOLOCK)
     WHERE l.sporttype = 1
           AND l.leaguename = LTRIM(RTRIM(@leaguename));
     IF ISNULL(@LeagueId, 0) = 0
         BEGIN
             SELECT @ErrMsg = 'Invalid League.', 
                    @ErrCode = 100;
             RETURN;
     END;
     IF EXISTS
     (
         SELECT 1
         FROM rmLeague WITH(NOLOCK)
         WHERE LeagueId = @LeagueId
     )
         BEGIN
             SELECT @ErrMsg = 'This League is exists.', 
                    @ErrCode = 102;
             RETURN;
     END;
     INSERT INTO rmLeague
     (LeagueId, 
      GroupId
     )
     VALUES
     (@LeagueId, 
      @GroupId
     );
     DECLARE @LogData NVARCHAR(500);
     SELECT @LogData = '<RMS_LeagueIns League="' + COALESCE(@leaguename, SPACE(1)) + '" ' + 'GroupId="' + COALESCE(CONVERT(VARCHAR(10), @GroupId), SPACE(1)) + '" ' + 'IP="' + COALESCE(@IP, SPACE(1)) + '" />';
     SET @endRun = GETDATE();
     SET @duration = DATEDIFF(MILLISECOND, @startRun, @endRun);
     EXEC DBLOG.bodb_CustomerLog.[dbo].[RMS_WriteLog_UserLog_RunSP] 
          @userid = @AdminID, 
          @actionid = 10500, 
          @TrackingValue = @LogData, 
          @duration = @duration;
GO