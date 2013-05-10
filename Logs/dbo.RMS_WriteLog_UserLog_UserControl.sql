CREATE PROCEDURE [dbo].[RMS_WriteLog_UserLog_UserControl]
    @CustID INT,
    @Doing NVARCHAR(500),
    @UserID INT = NULL,
    @TypeID TINYINT=0,
    @ActionID INT=NULL,
    @Duration INT = NULL
AS
/*
Created: 20120523@Elodie
Task : Write log for User Control in RMS
DB: DBLog.bodb_CustomerLog
Original: 

Revisions:
		
Parameter's Explanation:

*/
SET NOCOUNT ON
INSERT INTO  dbo.rmUserLog_UserControl
           ([CustID]
           ,[LogDate]
           ,[UserID]
           ,[TypeID]
           ,[ActionID]
           ,[Duration]
           ,[Doing])
     VALUES
            (@CustID
            ,GETDATE()
            ,@UserID
            ,@TypeID
            ,@ActionID
            ,@Duration
            ,@Doing
            )

GO
GRANT VIEW DEFINITION ON [dbo].[RMS_WriteLog_UserLog_UserControl] TO [vnteam]
GO
GRANT EXECUTE ON [dbo].[RMS_WriteLog_UserLog_UserControl] TO [bodbAdminNet]
GO
GRANT EXECUTE ON [dbo].[RMS_WriteLog_UserLog_UserControl] TO [bodbExtAccNet]