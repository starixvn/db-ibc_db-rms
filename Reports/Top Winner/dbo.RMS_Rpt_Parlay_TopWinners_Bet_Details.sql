ALTER PROCEDURE [dbo].[RMS_Rpt_Parlay_TopWinners_Bet_Details]
	@refno BIGINT
AS
	/*
		Created: Johnson	
		Date: 2013-08-13
		DB: DBRMS/bodb_RMS
		Task: View bet details 
		
		Revisions:
		- -20160926@Winnie: fix issue conflict refno with racing RedmineID: #64286
		Parameter's Explanation:
		
	*/
SET NOCOUNT ON
	DECLARE @BetListMP TABLE(
		transid BIGINT, 
		bettype int,
		homeid int,
		awayid int,
		hdp1 smallmoney, 
		hdp2 smallmoney, 
		odds smallmoney,
		betteam nvarchar(20),
		statusid int,
		status nvarchar(20),
		livehomescore smallint, 
		liveawayscore smallint, 
		liveindicator bit, 
		leagueid int,
		sporttype smallint,
		isNeutral bit,
		matchid int,
		matchcode nvarchar(50),
		betstatus nvarchar(50), 
		betcheck nvarchar(50)
	)
	
	if exists(select 1 from bodb02.dbo.bettransm with (nolock) where refno = @refno)
	BEGIN
		INSERT INTO @BetListMP
		SELECT
			bettrans.transid, 
			bettrans.bettype,
			match.homeid,
			match.awayid,
			bettrans.hdp1, 
			bettrans.hdp2, 
			bettrans.odds,
			bettrans.betteam,
			bettrans.statusid,
			bettrans.status,
			bettrans.livehomescore, 
			bettrans.liveawayscore, 
			bettrans.liveindicator, 
			match.leagueid,
			match.sporttype,
			match.isNeutral as IsNeutral,
			match.matchid,
			match.matchcode,
			match.betstatus,
			bettrans.betcheck
		from 
			(SELECT a.matchid,  Bettype, transid,hdp1, hdp2, odds, betteam, statusid,status,
					a.livehomescore,a.liveawayscore,liveindicator, betcheck
			FROM bodb02.dbo.BettransM a with (nolock)
			INNER JOIN bodb02.dbo.match m(NOLOCK) ON a.matchid=m.matchid
			WHERE refno=@refno AND m.sporttype<=99) AS bettrans
		INNER JOIN bodb02.dbo.match with (nolock) ON bettrans.matchid=match.matchid
	END
	
	if exists(select 1 from bodb02.dbo.bettransm14 with (nolock) where refno = @refno)
	BEGIN
		INSERT INTO @BetListMP
		SELECT
			bettrans.transid, 
			bettrans.bettype,
			match.homeid,
			match.awayid,
			bettrans.hdp1, 
			bettrans.hdp2, 
			bettrans.odds, 
			bettrans.betteam,
			bettrans.statusid,
			bettrans.status,
			bettrans.livehomescore, 
			bettrans.liveawayscore, 
			bettrans.liveindicator, 
			match.leagueid,
			match.sporttype,
			match.isNeutral as IsNeutral,
			match.matchid,
			match.matchcode,
			match.betstatus,
			bettrans.betcheck
		from 
			(SELECT a.matchid, Bettype, transid,hdp1, hdp2, odds, betteam, statusid, status,
					a.livehomescore,a.liveawayscore,liveindicator, betcheck
			FROM bodb02.dbo.BettransM14 a with (nolock)
			INNER JOIN bodb02.dbo.match14 m(NOLOCK) ON a.matchid=m.matchid
			WHERE refno=@refno AND m.sporttype<=99) AS bettrans
		INNER JOIN bodb02.dbo.match14 as match with (nolock) ON bettrans.matchid=match.matchid
	END
	
		
	if exists(select 1 from DBARC.bodb_archive.dbo.BettransM with (nolock) where refno = @refno)
	BEGIN
		INSERT INTO @BetListMP
		SELECT 
			bettrans.transid, 
			bettrans.bettype,
			match.homeid,
			match.awayid,
			bettrans.hdp1, 
			bettrans.hdp2, 
			bettrans.odds, 
			bettrans.betteam,
			bettrans.statusid,
			bettrans.status,
			bettrans.livehomescore, 
			bettrans.liveawayscore, 
			bettrans.liveindicator, 
			match.leagueid,
			match.sporttype,
			match.isNeutral,
			match.matchid,
			match.matchcode,
			match.betstatus,
			bettrans.betcheck
		from 
			(SELECT a.matchid, Bettype, transid,hdp1, hdp2, odds, betteam, a.statusid, status,
					a.livehomescore,a.liveawayscore,a.liveindicator, a.betcheck
			FROM DBARC.bodb_archive.dbo.BettransM a with (nolock)
			INNER JOIN DBARC.bodb_archive.dbo.match_bk m(NOLOCK) ON a.matchid=m.matchid
			WHERE refno=@refno AND m.sporttype<=99) AS bettrans
		INNER JOIN DBARC.bodb_Archive.dbo.match_bk as match with (nolock) ON bettrans.matchid=match.matchid
	END

		
	SELECT * FROM @BetListMP
	ORDER BY TransID desc
GO
GRANT EXECUTE ON  [dbo].[RMS_Rpt_Parlay_TopWinners_Bet_Details] TO [bodbRMSNet]