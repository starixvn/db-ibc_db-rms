ALTER PROCEDURE [dbo].[RMS_Rpt_Parlay_TopWinners_Bet_Details]
	@refno BIGINT
AS
	/*
		Created: Johnson	
		Date: 2013-08-13
		DB: DBRMS/bodb_RMS
		Task: View bet details 
		
		Revisions:
		
		Parameter's Explanation:
		
	*/
SET NOCOUNT ON
	DECLARE @Details TABLE(
		transid BIGINT, 
		bettype int,
		homeid int,
		awayid int,
		hdp1 smallmoney, 
		hdp2 smallmoney, 
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
		match.betstatus
	)
	DECLARE @refno BIGINT


GO
GRANT EXECUTE ON  [dbo].[RMS_Rpt_Parlay_TopWinners_Bet_Details] TO [bodbRMSNet]