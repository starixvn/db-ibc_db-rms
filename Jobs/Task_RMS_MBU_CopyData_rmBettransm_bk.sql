/*<info serverAlias="DBRMS-bodb_RMS" isFunction="0" isNested="1"></info>*/
ALTER PROCEDURE [dbo].[Task_RMS_MBU_CopyData_rmBettransm_bk]
	@winlostdate SMALLDATETIME
	,@ErrCode		INT = 0 OUTPUT
	,@ErrMsg		VARCHAR(4000) = '' OUTPUT
AS

/*
	Created: 20210319@Danny
	DB: DBRMS-bodb_RMS
	Task: RMS - Copy data from bettransm_bk to rmBettransm_bk

	Revisions:
		- 20210319@Danny: Initialize SP [RedmineID: #151319]
		- 20210809@Danny: Add column bettype,betteam into rmBettransm_bk [RedmineID: #159304]
*/

BEGIN
	SET NOCOUNT ON

	IF EXISTS (SELECT 1 FROM DBARC.bodb_archive.dbo.bettransm r WITH (NOLOCK) WHERE r.winlostdate = @winlostdate)
	BEGIN

		IF EXISTS (SELECT 1 FROM dbo.rmBettransm_bk WITH (NOLOCK) WHERE winlostdate = @winlostdate)
		BEGIN
			DELETE dbo.rmBettransm_bk WITH (ROWLOCK, UPDLOCK) WHERE winlostdate = @winlostdate
			DELETE dbo.rmMatch_bk WITH (ROWLOCK, UPDLOCK) WHERE eventdate = @winlostdate
		END

		BEGIN TRY
			DECLARE @SQL NVARCHAR(MAX)
			SELECT @SQL = 'SELECT transid,odds,stake,statusID,refno,winlostdate,matchid,matchdate,bettype,betteam
							FROM OPENQUERY(DBARC, ''SELECT  transid,odds,stake,statusID,refno,winlostdate,matchid,matchdate,bettype,betteam
													FROM bodb_archive.dbo.bettransm r WITH (NOLOCK)
													WHERE r.winlostdate = ''''' +CONVERT(VARCHAR(50),@winlostdate,120)+ ''''''')'

			INSERT INTO dbo.rmBettransm_bk
			(
				transid,
				odds,
				stake,
				statusID,
				refno,
				winlostdate,
				matchid,
				matchdate,
				bettype,
				betteam
			)
			EXEC (@SQL)


			DECLARE @SQL1 NVARCHAR(MAX)
			SELECT @SQL1 = 'SELECT matchid,leagueid,eventdate,ParentID,ChildMatchType,sporttype,GlobalShowTime,eventstatus
							FROM OPENQUERY(DBARC, ''SELECT  matchid,leagueid,eventdate,ParentID,ChildMatchType,sporttype,GlobalShowTime,eventstatus
													FROM bodb_archive.dbo.match_bk r WITH (NOLOCK)
													WHERE r.eventdate = ''''' +CONVERT(VARCHAR(50),@winlostdate,120)+ ''''''')'

			INSERT INTO dbo.rmMatch_bk
			(
				matchid,
				leagueid,
				eventdate,
				ParentID,
				ChildMatchType,
				sporttype,
				GlobalShowTime,
				eventstatus
			)
			 EXEC (@SQL1)
		

		END TRY
		BEGIN CATCH
			SELECT @ErrCode = 101, @ErrMsg = ERROR_MESSAGE()
			RETURN
		END CATCH
	END
	ELSE
	BEGIN
		RETURN
	END
END
GO
