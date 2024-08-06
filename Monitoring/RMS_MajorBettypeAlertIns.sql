/*<info serverAlias="DBRMS-bodb_RMS" executers="wsv_rms" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[RMS_MajorBettypeAlertIns]
	@MatchID INT = 0,
	@Bettype INT = 0,
	@Betcheck NVARCHAR(50) ='',
	@AlertType SMALLINT = 0,
	@Number INT = 0,
	@Times INT = 0,
	@HomeTotalStake MONEY = 0,
	@AwayTotalStake MONEY = 0,
	@DrawTotalStake MONEY = 0,
	@IsTest BIT = 0
AS

/*
	Created: Cherry
	Date: 2024-07-10
	DB: DBRMS/bodb_RMS
	Task: Notify/Alert by Major Bettype Amount
	
	Revisions:
		- 20240710@Cherry: Notify/Alert by Major Bettype Amount (#202238)
*/

BEGIN
	SET NOCOUNT ON
	
	INSERT INTO dbo.rmMajorBettypeAlert (
		AlertTime,
		MatchID,
		Bettype,
		Betcheck,
		AlertType,
		Number,
		Times,
		HomeStake,
		AwayStake,
		DrawStake,
		IsTest)
    VALUES( 
		GETDATE(),
		@MatchID,
		@Bettype,
		@Betcheck,
		@AlertType,
		@Number,
		@Times,
		@HomeTotalStake,
		@AwayTotalStake,
		@DrawTotalStake,
		@IsTest) 
	
END
GO