/*<info serverAlias="DBRMS-bodb_RMS" executers="bodbRMSNet" isFunction="1" isNested="1"></info>*/
 ALTER FUNCTION  [dbo].[f_RMS_strSplit]  
(
	@string NVARCHAR(MAX),
	@splitter CHAR( 1) 
)
RETURNS @res TABLE 
( 
	id INT PRIMARY KEY, 
	rank INT, 
	val NVARCHAR( 4000) 
)
AS
	/*
		Created: Johnson
		Date: 2012-05-09
		Task: function support to split string 
		DB: DBRMS/bodb_RMS,DBARC/bodb_Archive
		
		Revisions:
			- 20201126@Danny: @string NVARCHAR( 4000) to NVARCHAR( MAX) [RedmineID: #144471]		
		
		Parameter's Explanation:
	*/

BEGIN
     IF SUBSTRING ( @string, len ( @string), 1)<>@splitter
          SET @string= @string+@splitter
          
     DECLARE @start INT,
			 @word NVARCHAR(4000), 
			 @charindex INT, 
			 @i INT
			 
     SET @i=1
     SET @start=1
     SET @charindex= CHARINDEX( @splitter, @string, @start)
     
     WHILE (@charindex <> 0)
     BEGIN
          SET @word= SUBSTRING( @string, @start, @charindex - @start)
          SET @start= @charindex +1
          SET @charindex= CHARINDEX( @splitter, @string, @start)
          INSERT INTO @res  VALUES ( @start, @i, @word)
          SET @i=@i+1
     END
     RETURN
END
