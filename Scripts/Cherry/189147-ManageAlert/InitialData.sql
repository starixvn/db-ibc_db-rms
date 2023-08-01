/*<info serverAlias="DBRMS-bodb_RMS" isFunction="0" isNested="0"></info>*/
/*
Created by Cherry@20230620
Run at DBRMS@bodb_RMS 
Task: Manage Alert Letstalk Function (#189147)
*/
USE bodb_RMS
GO

INSERT INTO dbo.rmAlertType(AlertTypeID,AlertTypeName, Remark) VALUES
(1, 'Similar Bet', ''),
(2, 'Small Odds', ''),
(3, 'Potential Winning', ''),
(4, 'Last Pending Tickets', ''),
(5, 'Small League & Odds', '')

INSERT INTO dbo.rmAlertAction(ActionID,ActionName) VALUES
(0, 'No Action'),
(1, 'Send S&V'),
(2, 'Send OS'),
(3, 'Take Note'),
(4, 'Checked')
