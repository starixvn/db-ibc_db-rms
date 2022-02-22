/*<info serverAlias="DBRMS-bodb_RMS" executers="bodbRMSNet" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[RMS_ESport_LeagueSel]
	@SportType TINYINT = 43 -- E-sport
AS

/*
	Created: 20211221@Danny
	DB: DBRMS-bodb_RMS
	Task:  Monitor Performance for Event/Bettype/BetChoice (E-sports)

	Revisions:
		- 20211221@Danny: Init SP #165096

		EXEC dbo.RMS_ESport_LeagueSel

*/

BEGIN
	SET NOCOUNT ON
	DECLARE @yesterday DATE = DATEADD(DAY,-1, GETDATE())

	SELECT DISTINCT m.leagueid, l.leaguename 
	FROM bodb02.dbo.match m WITH(NOLOCK)
	INNER JOIN bodb02.dbo.League l  WITH(NOLOCK) ON m.leagueid = l.leagueid
	WHERE m.eventdate >= @yesterday AND m.sporttype = @SportType and m.eventstatus = 'running'
		AND l.isTest = 0 

END
GO