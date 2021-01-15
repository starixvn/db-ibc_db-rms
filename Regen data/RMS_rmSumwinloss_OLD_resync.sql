/*<info serverAlias="DBRMS-bodb_RMS" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE RMS_rmSumwinloss_OLD_resync
	@winlostdate SMALLDATETIME
/* 
	Created: 20210115@Danny
	DB: DBRMS.bodb_RMS
	Task: PRMS - PRMS - rmSumwinloss_OLD
	-- Regen data rmSumwinloss_OLD by Winlostdate 
	Revisions:	
		- 20210115@Danny: Regen data rmSumwinloss_OLD by Winlostdate  [RedmineID: #145926]
*/
AS

SET NOCOUNT ON

DECLARE @__query NVARCHAR(MAX), @__sqlCmd NVARCHAR(MAX)
SELECT  @__query = N''		
SELECT	@__query = @__query + N'EXEC RMS_ARC_rmSumwinloss_OLD_Sel_UAT1 @winlostdate'
SELECT	@__sqlCmd = N'EXECUTE DBARC.bodb_archive.dbo.sp_executesql @query, N''@winlostdate SMALLDATETIME'', @winlostdate'


	CREATE TABLE #rmSumWinloss_Old(
			[winlostdate] [smalldatetime] NOT NULL,
			[custid] [int] NOT NULL,
			[sporttype] [smallint] NULL,
			[statusid] [tinyint] NOT NULL,
			[combo] [tinyint] NOT NULL,
			[username] [varchar](30) NOT NULL,
			[currency] [tinyint] NULL,
			[stake] [money] NULL,
			[winlost] [money] NULL,
			[company_stake] [money] NULL,
			[company_winlost] [money] NULL,
			[actualrate] [float] NULL,
			[odds] [smallmoney] NULL,
			[betcount] [int] NULL,
			[recommend] [int] NULL,
			[parlaytype] [tinyint] NULL,
			[scomm] [money] NULL,
			[Extra_comm] [money] NULL,
			[Extra_stake] [money] NULL,
			[Extra_winlost] [money] NULL,
			[mrecommend] [int] NULL,
			[srecommend] [int] NULL,
			[awinlost] [money] NULL,
			[mwinlost] [money] NULL,
			[swinlost] [money] NULL,
			[actual_stake] [money] NULL,
			[playercomm] [money] NULL,
			[comm] [money] NULL,
			[acomm] [money] NULL
		) 


		INSERT INTO #rmSumWinloss_Old
		(
			winlostdate,custid,sporttype,statusID,combo,username,currency,stake,winlost
			,company_stake,company_winlost,actualrate,odds,betcount,recommend,parlaytype
			,scomm,Extra_comm,Extra_stake,Extra_winlost,
			mrecommend,srecommend,awinlost,mwinlost,swinlost,actual_stake,playercomm,comm,acomm
		)
		EXECUTE	sys.sp_executesql @__sqlCmd, N'@query NVARCHAR(MAX), @winlostdate SMALLDATETIME', @__query, @winlostdate


				
		MERGE dbo.rmSumWinloss_Old_UAT AS TARGET
		USING #rmSumWinloss_Old AS SOURCE
			ON		TARGET.WinlostDate	= SOURCE.WinlostDate
				AND TARGET.CustId		= SOURCE.CustId
				AND TARGET.sporttype	= SOURCE.sporttype
				AND TARGET.statusID		= SOURCE.statusID
				AND TARGET.combo		= SOURCE.combo
				AND TARGET.username		= SOURCE.username
				AND TARGET.currency		= SOURCE.currency
				AND TARGET.actualrate	= SOURCE.actualrate
				AND TARGET.recommend	= SOURCE.recommend
				AND TARGET.ParlayType	= SOURCE.ParlayType
					

		WHEN MATCHED THEN
			UPDATE SET 
				TARGET.mrecommend		= SOURCE.mrecommend,
				TARGET.srecommend		= SOURCE.srecommend,
				TARGET.stake			= SOURCE.stake,
				TARGET.winlost			= SOURCE.winlost,
				TARGET.company_stake	= SOURCE.company_stake,
				TARGET.company_winlost	= SOURCE.company_winlost,
				TARGET.odds				= SOURCE.odds,
				TARGET.betcount			= SOURCE.betcount,
				TARGET.scomm			= SOURCE.scomm,
				TARGET.Extra_comm		= SOURCE.Extra_comm,
				TARGET.Extra_stake		= SOURCE.Extra_stake,
				TARGET.Extra_winlost	= SOURCE.Extra_winlost,
				TARGET.awinlost			= SOURCE.awinlost,
				TARGET.mwinlost			= SOURCE.mwinlost,
				TARGET.swinlost			= SOURCE.swinlost,
				TARGET.actual_stake		= SOURCE.actual_stake,
				TARGET.playercomm		= SOURCE.playercomm,
				TARGET.comm				= SOURCE.comm,
				TARGET.acomm			= SOURCE.acomm

			WHEN NOT MATCHED BY TARGET THEN
			INSERT
				(
					winlostdate,
					custid,
					sporttype,
					statusID,
					combo,
					username,
					currency,
					stake,
					winlost,
					company_stake,
					company_winlost,
					actualrate,
					odds,
					betcount,
					recommend,
					parlaytype,
					scomm,
					Extra_comm,
					Extra_stake,
					Extra_winlost,
					mrecommend,
					srecommend,
					awinlost,
					mwinlost,
					swinlost,
					actual_stake,
					playercomm,
					comm,
					acomm
				)
				VALUES
				(
					SOURCE.winlostdate,
					SOURCE.custid,
					SOURCE.sporttype,
					SOURCE.statusID,
					SOURCE.combo,
					SOURCE.username,
					SOURCE.currency,
					SOURCE.stake,
					SOURCE.winlost,
					SOURCE.company_stake,
					SOURCE.company_winlost,
					SOURCE.actualrate,
					SOURCE.odds,
					SOURCE.betcount,
					SOURCE.recommend,
					SOURCE.parlaytype,
					SOURCE.scomm,
					SOURCE.Extra_comm,
					SOURCE.Extra_stake,
					SOURCE.Extra_winlost,
					SOURCE.mrecommend,
					SOURCE.srecommend,
					SOURCE.awinlost,
					SOURCE.mwinlost,
					SOURCE.swinlost,
					SOURCE.actual_stake,
					SOURCE.playercomm,
					SOURCE.comm,
					SOURCE.acomm
				) 
			OPTION (RECOMPILE);
	
		DROP TABLE #rmSumWinloss_Old

