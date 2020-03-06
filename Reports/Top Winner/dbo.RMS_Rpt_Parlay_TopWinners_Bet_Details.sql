/*<info serverAlias="DBRMS-bodb_RMS" executers="bodbRMSNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[RMS_Rpt_Parlay_TopWinners_Bet_Details]
	@transid	BIGINT
	,@refno		BIGINT
AS

/*
	Created: Johnson
	Date: 2013-08-13
	DB: DBRMS/bodb_RMS
	Task: View bet details 
		
	Revisions:
		- 20160926@Winnie: fix issue conflict refno with racing RedmineID: #64286
		- 20181224@Jacob: Esport 2, Add transdesc for bet list : #103001
		- 20191026@Jacob: Winloss by master RedmineID: [#122137]
		- 20200306@Percy: Fix issue missing data on bettransm/bettransm14/bettransmbk [RedmineID: #129935]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @BetListMP TABLE
    (
		transid			BIGINT
		,bettype		INT
		,homeid			INT
		,awayid			INT
		,hdp1			SMALLMONEY
		,hdp2			SMALLMONEY
		,odds			SMALLMONEY
		,betteam		NVARCHAR(20)
		,statusid		INT
		,[status]		NVARCHAR(20)
		,livehomescore	SMALLINT
		,liveawayscore	SMALLINT
		,liveindicator	BIT
		,leagueid		INT
		,sporttype		SMALLINT
		,isNeutral		BIT
		,matchid		INT
		,matchcode		NVARCHAR(50)
		,betstatus		NVARCHAR(50)
		,betcheck		NVARCHAR(50)
		,transdesc		NVARCHAR(1000)
		,stake			MONEY
    )

	IF EXISTS (SELECT 1 FROM bodb02.dbo.bettrans WITH (NOLOCK) WHERE transid = @transid)
	BEGIN
		IF EXISTS (SELECT 1 FROM bodb02.dbo.bettransm WITH (NOLOCK) WHERE refno = @refno)
		BEGIN
			INSERT INTO @BetListMP
            SELECT
				b.transid,b.bettype,m.homeid,m.awayid,b.hdp1,b.hdp2,b.odds,b.betteam
				,b.statusid,b.[status],b.livehomescore,b.liveawayscore,b.liveindicator
				,m.leagueid,m.sporttype,m.isNeutral,m.matchid,m.matchcode,m.betstatus,b.betcheck,b.transdesc
				,(b.stake * (1 - r.tpositiontaking) * r.actualrate) AS stake
            FROM
			(
				SELECT
					matchid,bettype,transid,hdp1,hdp2,odds,betteam,statusid,[status]
					,livehomescore,liveawayscore,liveindicator,betcheck,transdesc,refno,stake
				FROM bodb02.dbo.bettransm WITH (NOLOCK)
                WHERE refno = @refno
            ) AS b
                INNER JOIN bodb02.dbo.match m WITH (NOLOCK) ON b.matchid = m.matchid
                INNER JOIN bodb02.dbo.bettrans r WITH (NOLOCK) ON r.refno = b.refno
            WHERE r.transid = @transid
		END

		IF EXISTS (SELECT 1 FROM bodb02.dbo.bettransm14 WITH (NOLOCK) WHERE refno = @refno)
		BEGIN
			INSERT INTO @BetListMP
            SELECT
				b.transid,b.bettype,m.homeid,m.awayid,b.hdp1,b.hdp2,b.odds,b.betteam
				,b.statusid,b.[status],b.livehomescore,b.liveawayscore,b.liveindicator
				,m.leagueid,m.sporttype,m.isNeutral,m.matchid,m.matchcode,m.betstatus,b.betcheck,b.transdesc
				,(b.stake * (1 - r.tpositiontaking) * r.actualrate) AS stake
            FROM
			(
				SELECT
					matchid,bettype,transid,hdp1,hdp2,odds,betteam,statusid,[status]
					,livehomescore,liveawayscore,liveindicator,betcheck,transdesc,refno,stake
				FROM bodb02.dbo.bettransm14 WITH (NOLOCK)
                WHERE refno = @refno
            ) AS b
                INNER JOIN bodb02.dbo.match m WITH (NOLOCK) ON b.matchid = m.matchid
                INNER JOIN bodb02.dbo.bettrans r WITH (NOLOCK) ON r.refno = b.refno
            WHERE r.transid = @transid
		END
	END
	ELSE IF EXISTS (SELECT 1 FROM bodb02.dbo.bettrans14 WITH (NOLOCK) WHERE transid = @transid)
	BEGIN
		IF EXISTS (SELECT 1 FROM bodb02.dbo.bettransm WITH (NOLOCK) WHERE refno = @refno)
		BEGIN
			INSERT INTO @BetListMP
            SELECT
				b.transid,b.bettype,m.homeid,m.awayid,b.hdp1,b.hdp2,b.odds,b.betteam
				,b.statusid,b.[status],b.livehomescore,b.liveawayscore,b.liveindicator
				,m.leagueid,m.sporttype,m.isNeutral,m.matchid,m.matchcode,m.betstatus,b.betcheck,b.transdesc
				,(b.stake * (1 - r.tpositiontaking) * r.actualrate) AS stake
            FROM
			(
				SELECT
					matchid,bettype,transid,hdp1,hdp2,odds,betteam,statusid,[status]
					,livehomescore,liveawayscore,liveindicator,betcheck,transdesc,refno,stake
				FROM bodb02.dbo.bettransm WITH (NOLOCK)
                WHERE refno = @refno
            ) AS b
                INNER JOIN bodb02.dbo.match14 m WITH (NOLOCK) ON b.matchid = m.matchid
                INNER JOIN bodb02.dbo.bettrans14 r WITH (NOLOCK) ON r.refno = b.refno
            WHERE r.transid = @transid
		END

		IF EXISTS (SELECT 1 FROM bodb02.dbo.bettransm14 WITH (NOLOCK) WHERE refno = @refno)
		BEGIN
			INSERT INTO @BetListMP
            SELECT
				b.transid,b.bettype,m.homeid,m.awayid,b.hdp1,b.hdp2,b.odds,b.betteam
				,b.statusid,b.[status],b.livehomescore,b.liveawayscore,b.liveindicator
				,m.leagueid,m.sporttype,m.isNeutral,m.matchid,m.matchcode,m.betstatus,b.betcheck,b.transdesc
				,(b.stake * (1 - r.tpositiontaking) * r.actualrate) AS stake
            FROM
			(
				SELECT
					matchid,bettype,transid,hdp1,hdp2,odds,betteam,statusid,[status]
					,livehomescore,liveawayscore,liveindicator,betcheck,transdesc,refno,stake
				FROM bodb02.dbo.bettransm14 WITH (NOLOCK)
                WHERE refno = @refno
            ) AS b
                INNER JOIN bodb02.dbo.match14 m WITH (NOLOCK) ON b.matchid = m.matchid
                INNER JOIN bodb02.dbo.bettrans14 r WITH (NOLOCK) ON r.refno = b.refno
            WHERE r.transid = @transid
		END

		IF EXISTS (SELECT 1 FROM DBARC.bodb_Archive.dbo.bettransm WITH (NOLOCK) WHERE refno = @refno)
		BEGIN
			INSERT INTO @BetListMP
            SELECT
				b.transid,b.bettype,m.homeid,m.awayid,b.hdp1,b.hdp2,b.odds,b.betteam
				,b.statusid,b.[status],b.livehomescore,b.liveawayscore,b.liveindicator
				,m.leagueid,m.sporttype,m.isNeutral,m.matchid,m.matchcode,m.betstatus,b.betcheck,b.transdesc
				,(b.stake * (1 - r.tpositiontaking) * r.actualrate) AS stake
            FROM
			(
				SELECT
					matchid,bettype,transid,hdp1,hdp2,odds,betteam,statusid,[status]
					,livehomescore,liveawayscore,liveindicator,betcheck,transdesc,refno,stake
				FROM DBARC.bodb_Archive.dbo.bettransm WITH (NOLOCK)
                WHERE refno = @refno
            ) AS b
                INNER JOIN bodb02.dbo.match14 m WITH (NOLOCK) ON b.matchid = m.matchid
                INNER JOIN bodb02.dbo.bettrans14 r WITH (NOLOCK) ON r.refno = b.refno
            WHERE r.transid = @transid
		END
	END
	ELSE IF EXISTS (SELECT 1 FROM DBARC.bodb_Archive.dbo.bettrans_bk WITH (NOLOCK) WHERE transid = @transid)
	BEGIN
		IF EXISTS (SELECT 1 FROM bodb02.dbo.bettransm14 WITH (NOLOCK) WHERE refno = @refno)
		BEGIN
			INSERT INTO @BetListMP
            SELECT
				b.transid,b.bettype,m.homeid,m.awayid,b.hdp1,b.hdp2,b.odds,b.betteam
				,b.statusid,b.[status],b.livehomescore,b.liveawayscore,b.liveindicator
				,m.leagueid,m.sporttype,m.isNeutral,m.matchid,m.matchcode,m.betstatus,b.betcheck,b.transdesc
				,(b.stake * (1 - r.tpositiontaking) * r.actualrate) AS stake
            FROM
			(
				SELECT
					matchid,bettype,transid,hdp1,hdp2,odds,betteam,statusid,[status]
					,livehomescore,liveawayscore,liveindicator,betcheck,transdesc,refno,stake
				FROM bodb02.dbo.bettransm14 WITH (NOLOCK)
                WHERE refno = @refno
            ) AS b
                INNER JOIN DBARC.bodb_Archive.dbo.match_bk m WITH (NOLOCK) ON b.matchid = m.matchid
                INNER JOIN DBARC.bodb_Archive.dbo.bettrans_bk r WITH (NOLOCK) ON r.refno = b.refno
            WHERE r.transid = @transid
		END

		IF EXISTS (SELECT 1 FROM DBARC.bodb_Archive.dbo.bettransm WITH (NOLOCK) WHERE refno = @refno)
		BEGIN
			INSERT INTO @BetListMP
            SELECT
				b.transid,b.bettype,m.homeid,m.awayid,b.hdp1,b.hdp2,b.odds,b.betteam
				,b.statusid,b.[status],b.livehomescore,b.liveawayscore,b.liveindicator
				,m.leagueid,m.sporttype,m.isNeutral,m.matchid,m.matchcode,m.betstatus,b.betcheck,b.transdesc
				,(b.stake * (1 - r.tpositiontaking) * r.actualrate) AS stake
            FROM
			(
				SELECT
					matchid,bettype,transid,hdp1,hdp2,odds,betteam,statusid,[status]
					,livehomescore,liveawayscore,liveindicator,betcheck,transdesc,refno,stake
				FROM DBARC.bodb_Archive.dbo.bettransm WITH (NOLOCK)
                WHERE refno = @refno
            ) AS b
                INNER JOIN DBARC.bodb_Archive.dbo.match_bk m WITH (NOLOCK) ON b.matchid = m.matchid
                INNER JOIN DBARC.bodb_Archive.dbo.bettrans_bk r WITH (NOLOCK) ON r.refno = b.refno
            WHERE r.transid = @transid
		END
	END

	-- Return data
	SELECT
		transid,bettype,homeid,awayid,hdp1,hdp2,odds,betteam,statusid,STATUS
		,livehomescore,liveawayscore,liveindicator,leagueid,sporttype,isNeutral
		,matchid,matchcode,betstatus,betcheck,transdesc,stake
     FROM @BetListMP
     ORDER BY TransID DESC
END
GO