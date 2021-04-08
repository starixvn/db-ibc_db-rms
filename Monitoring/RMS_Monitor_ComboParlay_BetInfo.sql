/*<info serverAlias="DBRMS-bodb_RMS" executers="bodbRMSNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[RMS_Monitor_ComboParlay_BetInfo]
	@TransID		BIGINT	
 AS
	/*
		Created: Winnie
		Date: 20160425
		Task: Monitoring bets combo parlay of special members
		DB: DBRMS/bodb_RMS		
		Revisions:		
			- 20210303@Danny: Get BetInfo from trans_bk and bettrans14  [RedmineID: #148137]

	*/
SET NOCOUNT ON 
	SELECT betTeam, betCheck, hdp1, hdp2 FROM rmBettrans WITH (NOLOCK) WHERE transid=@TransID
	UNION
	SELECT betTeam, betCheck, hdp1, hdp2 FROM rmBettrans_Old WITH (NOLOCK) WHERE transid=@TransID



