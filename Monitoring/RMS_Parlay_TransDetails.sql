 ALTER PROCEDURE [dbo].[RMS_Parlay_TransDetails]
	@refno	BIGINT
 AS
	/*	
		Created: Johnson
		Date: 2012-10-25
		DB: DBRMS/bodb_RMS
		Task: get details selection of parlay tickets
		
		Revisions:
			- 20150407@Elodie: Add betcheck column [Red:#30605]
		Parameter's Explanation:
		
	*/
SET NOCOUNT ON

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
		(SELECT matchid,  Bettype, transid,hdp1, hdp2, odds, betteam, statusid, status,
				livehomescore,liveawayscore,liveindicator, betcheck
		FROM bodb02.dbo.BettransM with (nolock)
		WHERE refno=@refno ) AS bettrans
	INNER JOIN bodb02.dbo.match with (nolock) ON bettrans.matchid=match.matchid
	UNION 
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
		(SELECT matchid,  Bettype, transid,hdp1, hdp2, odds, betteam, statusid, status,
				livehomescore,liveawayscore,liveindicator, betcheck
		FROM bodb02.dbo.BettransM14 with (nolock)
		WHERE refno=@refno ) AS bettrans
	INNER JOIN bodb02.dbo.match14  as [match] with (nolock) ON bettrans.matchid=match.matchid

GO
GRANT EXECUTE ON [dbo].[RMS_Parlay_TransDetails] TO [bodbRMSNet]