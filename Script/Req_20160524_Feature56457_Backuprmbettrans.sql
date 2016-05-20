USE [bodb_RMS]
GO

/****** Object:  Table [dbo].[rmBettrans]    Script Date: 5/25/2016 10:40:37 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[rmBettrans_backup](
	[transid] [bigint] NOT NULL,
	[custid] [int] NOT NULL,
	[transdate] [datetime] NOT NULL,
	[oddsid] [int] NOT NULL,
	[hdp1] [smallmoney] NULL,
	[hdp2] [smallmoney] NULL,
	[odds] [smallmoney] NULL,
	[stake] [money] NOT NULL,
	[status] [nvarchar](10) NULL,
	[winlost] [money] NULL,
	[awinlost] [money] NULL,
	[mwinlost] [money] NULL,
	[playercomm] [money] NULL,
	[comm] [money] NULL,
	[acomm] [money] NULL,
	[apositiontaking] [smallmoney] NULL,
	[mpositiontaking] [smallmoney] NULL,
	[tpositiontaking] [smallmoney] NULL,
	[playerdiscount] [decimal](9, 8) NULL,
	[discount] [decimal](9, 8) NULL,
	[adiscount] [decimal](9, 8) NULL,
	[livehomescore] [smallint] NULL,
	[liveawayscore] [smallint] NULL,
	[liveindicator] [bit] NULL,
	[betteam] [nvarchar](10) NULL,
	[creator] [int] NOT NULL,
	[refno] [bigint] NOT NULL,
	[comstatus] [nvarchar](20) NULL,
	[winlostdate] [smalldatetime] NULL,
	[betfrom] [nvarchar](1) NULL,
	[betcheck] [nvarchar](50) NULL,
	[checktime] [datetime] NULL,
	[oddsspread] [smallmoney] NULL,
	[actualrate] [float] NULL,
	[matchid] [int] NULL,
	[recommend] [int] NOT NULL,
	[mrecommend] [int] NOT NULL,
	[ruben] [tinyint] NULL,
	[betid] [bigint] NULL,
	[statuswinlost] [tinyint] NULL,
	[modds] [smallmoney] NULL,
	[bettype] [smallint] NULL,
	[betdaqid] [bigint] NULL,
	[tstamp] [timestamp] NULL,
	[actual_stake] [money] NULL,
	[currency] [tinyint] NULL,
	[ip] [nvarchar](15) NULL,
	[transdesc] [nvarchar](300) NULL,
	[sdiscount] [decimal](9, 8) NULL,
	[scomm] [money] NULL,
	[spositiontaking] [smallmoney] NULL,
	[swinlost] [money] NULL,
	[srecommend] [int] NOT NULL,
	[Username] [nvarchar](50) NULL,
	[CurrencyName] [nvarchar](50) NULL,
	[virtualrate] [float] NOT NULL,
	[oddstype] [tinyint] NULL,
	[statusID] [tinyint] NULL,
	[currency2] [tinyint] NULL,
	[balance] [money] NULL,
	[SecAcceptFlag] [bit] NULL,
	[transid2] [bigint] NULL,
	[combo] [int] NULL,
	[odds2] [money] NULL
	
) ON [rmDATA]

GO
INSERT INTO [dbo].[rmBettrans_backup]
           ([transid]
           ,[custid]
           ,[transdate]
           ,[oddsid]
           ,[hdp1]
           ,[hdp2]
           ,[odds]
           ,[stake]
           ,[status]
           ,[winlost]
           ,[awinlost]
           ,[mwinlost]
           ,[playercomm]
           ,[comm]
           ,[acomm]
           ,[apositiontaking]
           ,[mpositiontaking]
           ,[tpositiontaking]
           ,[playerdiscount]
           ,[discount]
           ,[adiscount]
           ,[livehomescore]
           ,[liveawayscore]
           ,[liveindicator]
           ,[betteam]
           ,[creator]
           ,[refno]
           ,[comstatus]
           ,[winlostdate]
           ,[betfrom]
           ,[betcheck]
           ,[checktime]
           ,[oddsspread]
           ,[actualrate]
           ,[matchid]
           ,[recommend]
           ,[mrecommend]
           ,[ruben]
           ,[betid]
           ,[statuswinlost]
           ,[modds]
           ,[bettype]
           ,[betdaqid]
           ,[actual_stake]
           ,[currency]
           ,[ip]
           ,[transdesc]
           ,[sdiscount]
           ,[scomm]
           ,[spositiontaking]
           ,[swinlost]
           ,[srecommend]
           ,[Username]
           ,[CurrencyName]
           ,[virtualrate]
           ,[oddstype]
           ,[statusID]
           ,[currency2]
           ,[balance]
           ,[SecAcceptFlag]
           ,[transid2]
           ,[combo]
           ,[odds2]
           )
SELECT
			[transid]
           ,[custid]
           ,[transdate]
           ,[oddsid]
           ,[hdp1]
           ,[hdp2]
           ,[odds]
           ,[stake]
           ,[status]
           ,[winlost]
           ,[awinlost]
           ,[mwinlost]
           ,[playercomm]
           ,[comm]
           ,[acomm]
           ,[apositiontaking]
           ,[mpositiontaking]
           ,[tpositiontaking]
           ,[playerdiscount]
           ,[discount]
           ,[adiscount]
           ,[livehomescore]
           ,[liveawayscore]
           ,[liveindicator]
           ,[betteam]
           ,[creator]
           ,[refno]
           ,[comstatus]
           ,[winlostdate]
           ,[betfrom]
           ,[betcheck]
           ,[checktime]
           ,[oddsspread]
           ,[actualrate]
           ,[matchid]
           ,[recommend]
           ,[mrecommend]
           ,[ruben]
           ,[betid]
           ,[statuswinlost]
           ,[modds]
           ,[bettype]
           ,[betdaqid]
           ,[actual_stake]
           ,[currency]
           ,[ip]
           ,[transdesc]
           ,[sdiscount]
           ,[scomm]
           ,[spositiontaking]
           ,[swinlost]
           ,[srecommend]
           ,[Username]
           ,[CurrencyName]
           ,[virtualrate]
           ,[oddstype]
           ,[statusID]
           ,[currency2]
           ,[balance]
           ,[SecAcceptFlag]
           ,[transid2]
           ,[combo]
           ,[odds2]
           
		   FROM rmBettrans(NOLOCK)



