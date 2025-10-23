/*<info serverAlias="DBRMS-bodb_RMS" isFunction="0" isNested="1"></info>*/
ALTER PROCEDURE [dbo].[Task_RMS_MBU_SumData_rmSumWinloss]
	@winlostdate	SMALLDATETIME
	,@ErrCode		INT = 0 OUTPUT
	,@ErrMsg		VARCHAR(4000) = '' OUTPUT
AS

/*
	Created: 20200512@Percy
	DB: DBRMS-bodb_RMS
	Task: RMS - Sum data of rmSumWinloss

	Revisions:
		- 20200512@Percy: Initialize SP [RedmineID: #130275]
		- 20201214@Danny: Separate Data of Virtual Soccer & Virtual Basketball [RedmineID: #145926]
		- 20200203@Danny: Prepare Separate Data GOF for deposit [RedmineID: #149966]
		- 20200203@Danny: Separate Data GOF for deposit [RedmineID: #149966]
		- 20220519@Danny: add column LiveIndicator [RedmineID: #172691]
		- 20220917@Sophia: Fix Divide by Zero [Redmine: #177934]
		- 20231020@Cherry: Parlay Generator (#195498)
		- 20231201@Cherry: Parlay Type for Parlay Boost (#197680)
		- 20240115@Cherry: Change attribute for Parlay Generator (#199766)
		- 20250410@Cherry: Extend data type Currency (#222189)
		- 20251020@Cherry: Integrate Hybrid Parlay (#242165)
*/

BEGIN
	SET NOCOUNT ON

	IF NOT EXISTS (SELECT 1 FROM dbo.rmBettrans WITH (NOLOCK) WHERE winlostdate = @winlostdate)
		RETURN

	-- Gen data
	BEGIN TRY
		CREATE TABLE #rmBettrans(
				[transid] [bigint] NOT NULL,
				[winlostdate] [smalldatetime] NOT NULL,
				[custid] [int] NOT NULL,
				[transid2] [bigint] NULL,
				[statusid] [tinyint] NOT NULL,
				[modds] [smallmoney] NULL,
				[bettype] [smallint] NULL,
				[betcheck] [nvarchar](50) NULL,
				[oddsspread] [smallmoney] NULL,
				[betteam] [nvarchar](10) NULL,
				[hdp2] [smallmoney] NULL,
				[username] [varchar](30) NOT NULL,
				[currency] [smallint] NULL,
				[stake] [money] NULL,
				[winlost] [money] NULL,
				[tpositiontaking] [smallmoney] NULL,
				[actualrate] [float] NULL,
				[odds] [smallmoney] NULL,
				[recommend] [int] NULL,
				[bac] [int] NULL,
				[scomm] [money] NULL,
				[epositiontaking] [smallmoney] NULL,
				[mrecommend] [int] NULL,
				[srecommend] [int] NULL,
				[awinlost] [money] NULL,
				[mwinlost] [money] NULL,
				[swinlost] [money] NULL,
				[actual_stake] [money] NULL,
				[playercomm] [money] NULL,
				[comm] [money] NULL,
				[acomm] [money] NULL,
				[livehomescore] [smallint] NULL,
				[liveindicator] [bit] NULL
			)

		CREATE TABLE #rmSumWinloss(
				[winlostdate] [smalldatetime] NOT NULL,
				[custid] [int] NOT NULL,
				[sporttype] [smallint] NULL,
				[statusid] [tinyint] NOT NULL,
				[combo] [tinyint] NOT NULL,
				[username] [varchar](30) NOT NULL,
				[currency] [smallint] NULL,
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
				[acomm] [money] NULL,
				[LiveIndicator] [smallint] NULL
			)

		 INSERT INTO #rmBettrans(
				transid,
				[winlostdate],
				[custid],
				[transid2],
				[statusid],
				[modds],
				[bettype],
				[betcheck],
				[oddsspread],
				[betteam],
				[hdp2],
				[username],
				[currency],
				[stake],
				[winlost],
				[tpositiontaking],
				[actualrate],
				[odds],
				[recommend],
				[bac],
				[scomm],
				[epositiontaking],
				[mrecommend],
				[srecommend],
				[awinlost],
				[mwinlost],
				[swinlost],
				[actual_stake],
				[playercomm],
				[comm] ,
				[acomm],
				[livehomescore],
				[liveindicator]
			)
		SELECT
				transid,
				[winlostdate],
				[custid],
				[transid2],
				[statusid],
				[modds],
				[bettype],
				[betcheck],
				[oddsspread],
				[betteam],
				[hdp2],
				[username],
				[currency],
				[stake],
				[winlost],
				[tpositiontaking],
				[actualrate],
				[odds],
				[recommend],
				ISNULL(TRY_CAST(TRY_CAST(ExtraInfo AS XML).value('(/p1/@bac)[1]', 'VARCHAR(50)') AS INT),0),
				[scomm],
				[epositiontaking],
				[mrecommend],
				[srecommend],
				[awinlost],
				[mwinlost],
				[swinlost],
				[actual_stake],
				[playercomm],
				[comm] ,
				[acomm],
				[livehomescore],
				[liveindicator]
		FROM dbo.rmBettrans  WITH (NOLOCK)
		WHERE winlostdate = @winlostdate
			AND statusID IN (111, 112, 113)

		INSERT INTO #rmSumWinloss
		(
			winlostdate,custid,sporttype,statusID,combo,username,currency,stake,winlost
			,company_stake,company_winlost,actualrate,odds,betcount,recommend,parlaytype
			,scomm,Extra_comm,Extra_stake,Extra_winlost,
			mrecommend,srecommend,awinlost,mwinlost,swinlost,actual_stake,playercomm,comm,acomm, LiveIndicator
		)
		SELECT
			b.winlostdate
			,b.custid
			,b.transid2 AS sporttype
			,b.statusID
			,CASE WHEN b.bettype = 29 AND b.betcheck IS NULL THEN LEN(b.betteam) ELSE b.hdp2 END AS combo
			,b.username
			,b.currency
			,SUM(b.stake) AS stake
			,SUM(b.winlost) AS winlost
			,SUM(b.stake * (1 - b.tpositiontaking)) AS company_stake
			,SUM(-(b.winlost - b.stake) * (1 - b.tpositiontaking)) AS company_winlost
			,b.actualrate
			,SUM(b.modds) AS odds
			,COUNT(1) AS betcount
			,b.recommend
			,CASE
				WHEN b.bettype = 29 AND b.betteam = N'1' AND b.bac|16 = b.bac AND b.oddsspread = 2 THEN 78 --Parlay Generator & Boost
				WHEN b.bettype = 29 AND b.betteam = N'1' AND b.oddsspread = 2 THEN 8 --Parlay Boost
				WHEN b.bettype = 29 AND b.betteam = N'1' AND b.bac|16 = b.bac THEN 7 --Parlay Generator
				WHEN b.bettype = 29 AND b.betteam = N'1' AND b.oddsspread = 1 THEN 6 --GOF
				WHEN b.bettype = 29 AND b.betteam = N'1' AND b.oddsspread = 3 THEN 9 --Hybrid Parlay
				WHEN b.bettype = 29 AND b.betteam = N'1' THEN 2
				WHEN b.bettype = 29 AND b.betteam <> N'1' THEN 3
				WHEN b.bettype = 38 THEN 4
				WHEN b.bettype = 376 THEN 5
				ELSE 0 END AS ParlayType
			,SUM(b.scomm) AS scomm
			,SUM(CASE WHEN b.tpositiontaking = 1 THEN 0 ELSE b.scomm * CONVERT(DECIMAL(9,8), b.epositiontaking) / (1 - b.tpositiontaking) END) AS Extra_comm
			,SUM(b.stake * CONVERT(DECIMAL(9,8), b.epositiontaking)) AS Extra_stake
			,SUM(-(b.winlost - b.stake) * CONVERT(DECIMAL(9,8), b.epositiontaking)) AS Extra_winlost,
			b.mrecommend,
			b.srecommend,
			SUM(awinlost) as awinlost,
			SUM(mwinlost) as mwinlost,
			SUM(swinlost) as swinlost,
			SUM(actual_stake) as actual_stake,
			SUM(playercomm) as playercomm,
			SUM(comm) as comm,
			SUM(acomm) as acomm,
			CASE WHEN b.bettype = 29 THEN b.livehomescore ELSE b.liveindicator END liveindicator
		FROM #rmBettrans b
		WHERE b.winlostdate = @winlostdate
			AND b.statusID IN (111, 112, 113)
		GROUP BY
			b.winlostdate
			,b.custid
			,b.transid2
			,b.statusID
			,CASE WHEN b.bettype = 29 AND b.betcheck IS NULL THEN LEN(b.betteam) ELSE b.hdp2 END
			,b.username
			,b.currency
			,b.actualrate
			,b.recommend
			,CASE
				WHEN b.bettype = 29 AND b.betteam = N'1' AND b.bac|16 = b.bac AND b.oddsspread = 2 THEN 78 --Parlay Generator & Boost
				WHEN b.bettype = 29 AND b.betteam = N'1' AND b.oddsspread = 2 THEN 8 --Parlay Boost
				WHEN b.bettype = 29 AND b.betteam = N'1' AND b.bac|16 = b.bac THEN 7 --Parlay Generator
				WHEN b.bettype = 29 AND b.betteam = N'1' AND b.oddsspread = 1 THEN 6 --GOF
				WHEN b.bettype = 29 AND b.betteam = N'1' AND b.oddsspread = 3 THEN 9 --Hybrid Parlay
				WHEN b.bettype = 29 AND b.betteam = N'1' THEN 2
				WHEN b.bettype = 29 AND b.betteam <> N'1' THEN 3
				WHEN b.bettype = 38 THEN 4
				WHEN b.bettype = 376 THEN 5
				ELSE 0 END,
			b.mrecommend,
			b.srecommend,
			CASE WHEN b.bettype = 29 THEN b.livehomescore ELSE b.liveindicator END;

		-------------------------
		MERGE dbo.rmSumWinloss AS TARGET
			USING #rmSumWinloss AS SOURCE
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
					AND TARGET.liveindicator	= SOURCE.liveindicator
					

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
						acomm,
						LiveIndicator
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
						SOURCE.acomm,
						SOURCE.LiveIndicator
					) 
				WHEN NOT MATCHED BY SOURCE AND TARGET.winlostdate = @winlostdate THEN DELETE
				;

		DROP TABLE #rmSumWinloss
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = 101, @ErrMsg = ERROR_MESSAGE()
		RETURN
	END CATCH
END
GO