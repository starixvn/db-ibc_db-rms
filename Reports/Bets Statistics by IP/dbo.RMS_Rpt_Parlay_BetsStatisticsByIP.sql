/*<info serverAlias="DBRMS-bodb_RMS" executers="bodbRMSNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[RMS_Rpt_Parlay_BetsStatisticsByIP]
	@IP			VARCHAR(30)
	,@fromdate	DATETIME
AS

/*
	Created: 20140418@Johnson
	DB: DBRMS/bodb_RMS
	Task: Get report customers bets by ip

	Revisions:	
		- 20200510@Percy: Change condition of transdate [RedmineID: #133961]
*/

BEGIN 
	SET NOCOUNT ON 
	
	SELECT
		custid
		,username
		,SUM(CASE WHEN liveawayscore = 1 THEN 1 ELSE 0 END) as cnt_soccer
		,SUM(CASE WHEN liveawayscore IN (2,3) THEN 1 ELSE 0 END) as cnt_others
	FROM dbo.rmBettrans WITH (NOLOCK)
	WHERE IP = @IP
		AND transdate >= @fromdate AND transdate < DATEADD(DAY, 1, @fromdate)
	GROUP BY custid, username
END
GO