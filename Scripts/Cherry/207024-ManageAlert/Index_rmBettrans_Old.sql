/*<info serverAlias="DBRMS-bodb_RMS" executers="wsv_rms" isFunction="0" isNested="0"></info>*/
USE [bodb_RMS]
GO

/****** Object:  Index [PK_rmBettrans_Old]    Script Date: 6/26/2024 1:28:38 PM ******/
ALTER TABLE [dbo].[rmBettrans_Old] DROP CONSTRAINT [PK_rmBettrans_Old]
GO

CREATE UNIQUE NONCLUSTERED INDEX [IX_TransID] ON [dbo].[rmBettrans_Old]
(
	[transid] ASC
)
INCLUDE([hdp2],[refno],[transid2]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [rmDATA]
GO


