ALTER PROCEDURE [dbo].[RMS_CustomerSelInfoByUsername]
	@username NVARCHAR(50),
	@custid		INT = 0 OUTPUT,
	@roleid		INT = 0 OUTPUT
AS
	/*
		Created: Johnson
		Date: 2013-05-14
		Task: get custid, roleid by username
		DB: DBACC/bodb02
		
		Revisions:
		
		Parameter's Explanation:
	*/
SET NOCOUNT ON 

	SELECT @custid = custid, @roleid = roleid
	FROM customer WITH(NOLOCK) 
	WHERE username = @username

GO
GRANT EXECUTE ON  [dbo].[RMS_CustomerSelInfoByUsername] TO [bodbRMSNet]