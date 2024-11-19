/*<info serverAlias="DBRMS-bodb_RMS" isFunction="0" isNested="1"></info>*/

ALTER TABLE bodb_rms.dbo.rmUserTrackingLog
ADD LogType INT

UPDATE bodb_rms.dbo.rmUserTrackingLog WITH(ROWLOCK, UPDLOCK)
SET LogType = 0