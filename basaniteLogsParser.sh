SELECT * FROM searchrequest;
SELECT * FROM sharepermissions; --WHERE entitytype	= 'SearchRequest'; 99 AND rights = ???	 
	--id	entityid	entitytype	sharetype	param1	param2	rights
SELECT * FROM cwd_directory;
SELECT * FROM cwd_membership;
SELECT * FROM licenserolesgroup;
SELECT * FROM app_user;
SELECT * FROM cwd_user; --Active User
	--id	directory_id	user_name	lower_user_name	active	created_date	updated_date	first_name	lower_first_name	last_name	lower_last_name	display_name	lower_display_name	email_address	lower_email_address	credential	deleted_externally	external_id
SELECT * FROM cwd_directory;
SELECT * FROM cwd_user_attributes order by attribute_name ; WHERE attribute_name = 'login.lastLoginMillis';  --Last User Login Date, 'login.count'
SELECT * FROM portalpage;
	--id	username	pagename	description	"sequence"	fav_count	layout	ppversion
SELECT * FROM project;
SELECT * FROM "AO_60DB71_RAPIDVIEW";
SELECT * FROM portalpage; --System Dashboard,...
SELECT * FROM portletconfiguration;
SELECT * FROM gadgetuserpreference;

--NOTES: Critical Data Center Warning
	--Do not directly DELETE via SQL: This causes index desynchronization and breaks system integrity.
	--Safe Cleanup: Export the list of filter_id values and use the Administration > System > Shared Items > Filters UI to reassign or delete filters safely.



--To find the last login date for users in Jira Data Center, you must query the cwd_user_attributes table, where Jira stores login timestamps as an Unix epoch millisecond string under the attribute name login.lastLoginMillis
--# Last Login Date. Find the last login date for a user in Jira server: https://support.atlassian.com/jira/kb/find-the-last-login-date-for-a-user-in-jira-server/
--PostgreSQL:
SELECT d.directory_name AS "Directory", u.user_name AS "Username", to_timestamp(CAST(attribute_value AS BIGINT)/1000) AS "Last Login" 
	FROM cwd_user u
	JOIN ( SELECT DISTINCT child_name FROM cwd_membership m JOIN licenserolesgroup gp ON m.lower_parent_name = gp.GROUP_ID ) AS m ON m.child_name = u.user_name
	JOIN ( SELECT *  FROM cwd_user_attributes ca WHERE attribute_name = 'login.lastLoginMillis' ) AS a ON a.user_id = u.id
	JOIN cwd_directory d ON u.directory_id = d.id ORDER BY "Last Login" DESC;
--MSSQL:
SELECT d.directory_name AS "Directory", u.user_name AS "Username", DATEADD(second, cast(attribute_value as bigint)/1000,{d '1970-01-01'})  AS "Last Login"
	FROM dbo.cwd_user u
	JOIN (SELECT DISTINCT child_name FROM dbo.cwd_membership m JOIN dbo.licenserolesgroup gp ON m.lower_parent_name = gp.GROUP_ID ) AS m ON m.child_name = u.user_name
	JOIN (SELECT * FROM dbo.cwd_user_attributes ca WHERE attribute_name = 'login.lastLoginMillis') AS a ON a.user_id = u.ID
	JOIN dbo.cwd_directory d ON u.directory_id = d.ID ORDER BY "Last Login" DESC;
--If you want to add the "active" and "never logged in" users to this list, consider the following query:
SELECT d.directory_name AS "Directory",  u.user_name AS "Username", u.active AS "Active", to_timestamp(CAST(attribute_value AS BIGINT)/1000) AS "Last Login"
	FROM cwd_user u
	JOIN ( SELECT DISTINCT child_name FROM cwd_membership m JOIN licenserolesgroup gp ON m.lower_parent_name = gp.GROUP_ID ) AS m ON m.child_name = u.user_name
	LEFT JOIN ( SELECT * FROM cwd_user_attributes ca WHERE attribute_name = 'login.lastLoginMillis' ) AS a ON a.user_id = u.ID
	JOIN cwd_directory d ON u.directory_id = d.id ORDER BY "Last Login" DESC;
	--Never Logged In: A NULL result means the user has never logged into the instance."
	--Remember Me" Caveat: Timestamps reflect the last login with credentials, not necessarily the last active session.
	--Active Status: Filter for active users using WHERE u.active = 1 for license auditing.



--Jira Datacenter SQL private filters created by users and not shared, ADD: AND -Author deactivated
--To find private filters look for records in the searchrequest table that do not have a matching entry in the sharepermissions table
SELECT sr.id, sr.filtername, sr.authorname, sr.reqcontent 
	FROM searchrequest sr WHERE sr.id NOT IN (SELECT entityid FROM sharepermissions WHERE entitytype = 'SearchRequest');
--Use a LEFT JOIN to achieve the same result by isolating NULL rows on the shared table side
--How to list Private and Shared filters in Jira from Database? https://support.atlassian.com/jira/kb/how-to-list-private-and-shared-filters-in-jira-from-database/
	-- Scenario #1: JIRA administrators are unable to view or modify private filters and dashboards. This limitation can become a significant issue if a user leaves the company and the administrator needs to access the user’s private filters and dashboards. These private items are not displayed under Shared Filters or Shared Dashboards, creating potential blockers for administrative tasks.
	-- Scenario #2: When managing a large number of filters in JIRA, distinguishing between private and shared filters is essential, particularly during clean-up activities. This article provides specific database queries to help identify which filters are private and which are shared.
--For private Dashboard:
SELECT * FROM portalpage WHERE id NOT IN (SELECT entityid FROM sharepermissions WHERE entitytype = 'PortalPage'); --(postgres, MSSQL)  
--For private Filter, there are 2 ways to fetch the same result. Either Query #1 or Query #2 can be used to fetch the requested details:
--Query #1:
SELECT sr.filtername, sr .* FROM searchrequest sr WHERE id NOT IN (SELECT entityid FROM sharepermissions); --(postgres)
SELECT sr.filtername, sr .* FROM searchrequest sr LEFT JOIN sharepermissions sp ON sr.id = sp.entityid WHERE sp.entityid IS NULL; --(postgres, MSSQL)
--Query #2: 
SELECT sr.filtername, sr .* FROM searchrequest sr WHERE id NOT IN (SELECT entityid from sharepermissions WHERE entitytype='SearchRequest'); --(postgres)
SELECT sr.filtername, sr.* FROM searchrequest sr LEFT JOIN sharepermissions sp ON sr.id = sp.entityid AND sp.entitytype = 'SearchRequest' WHERE sp.entityid IS NULL; --(postgres, MSSQL)

--To isolate private filters (not shared with anyone) that are owned specifically by deactivated users in Jira Data Center, you must cross-reference three main tables:
--https://community.atlassian.com/forums/Jira-articles/Identify-Private-Filters-Owned-by-Inactive-Users-in-Jira-Data/ba-p/3233747 --Identify Private Filters Owned by Inactive Users in Jira Data Center Using ScriptRunner 
	--searchrequest: Contains all saved filters.
	--sharepermissions: Records what permissions/shares exist for a filter. A lack of record indicates the filter is private
	--cwd_user & app_user: Contains user statuses. Jira maps filter authorship via the immutable app_user.user_key, which must be joined against cwd_user.lower_user_name to evaluate the user's active = 0 status.
--The following SQL identifies private filters (no sharepermissions record) owned by users with active = 0 in cwd_user
SELECT sr.id, sr.filtername, cu.user_name, sr.reqcontent --SELECT cu.user_name, count (cu.user_name) cnt --Groupped by author
	FROM searchrequest sr
	JOIN app_user au ON sr.authorname = au.user_key
	JOIN cwd_user cu ON au.lower_user_name = cu.lower_user_name
	LEFT JOIN sharepermissions sp ON sr.id = sp.entityid AND sp.entitytype = 'SearchRequest'
	WHERE cu.active = 0 AND sp.entityid IS NULL; 	--GROUP BY cu.user_name ORDER BY cnt;



--Jira filters owned by invalid users
--https://support.atlassian.com/portfolio-insights/docs/jira-filters-owned-by-invalid-users/
SELECT DISTINCT sr.filtername AS "Filter name", sr.username AS "Filter username", sr.authorname AS "Filter author", cwu.lower_email_address AS "Filter inactive user email address", cwu.display_name AS "Filter inactive user display name", 
	au.user_key AS "Filter inactive user user key", CASE WHEN cwu.active = 0 THEN 'Inactive' ELSE 'Active' END AS "User status", sr.reqcontent AS "Filter JQL"
FROM cwd_user cwu
INNER JOIN app_user au ON (cwu.lower_user_name = au.lower_user_name)
JOIN searchrequest sr ON ((sr.username = cwu.lower_user_name OR sr.username = au.user_key)
OR ( sr.authorname = cwu.lower_user_name OR sr.authorname = au.user_key) )
WHERE cwu.active = 0;





--Query or ways to find filters which linked with any dashboard or board
--https://community.atlassian.com/forums/Jira-questions/Query-or-ways-to-find-filters-which-linked-with-any-dashboard-or/qaq-p/1064874
--This returns the board name's and id numbers along with the filter names and other filter details:
SELECT "AO_60DB71_RAPIDVIEW"."NAME" as BoardName, "AO_60DB71_RAPIDVIEW"."ID" as BoardID, sr.* 
	from searchrequest sr
	join "AO_60DB71_RAPIDVIEW" on "AO_60DB71_RAPIDVIEW"."SAVED_FILTER_ID" = sr.id;

SELECT pp.id, pp.username, pp.pagename, s.filtername, s.id, gup.USERPREFVALUE 
	FROM portalpage pp
	JOIN portletconfiguration pc on pp.id = pc.portalpage
	JOIN gadgetuserpreference gup on pc.ID = gup.portletconfiguration
	JOIN searchrequest s on gup.userprefvalue=s.filtername;

SELECT pp.id, pp.username, pp.pagename, s.filtername, s.id, gup.USERPREFVALUE 
	FROM portalpage pp
	JOIN portletconfiguration pc on pp.id = pc.portalpage
	JOIN gadgetuserpreference gup on pc.ID = gup.portletconfiguration
	JOIN searchrequest s on cast(s.ID AS text) = SUBSTRING(gup.USERPREFVALUE,8,5)
	WHERE gup.USERPREFVALUE like 'filter%' order by pp.ID;


--# Project does not exist

