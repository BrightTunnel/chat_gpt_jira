--Jira Datacenter SQL private filters created by users and not shared, AND -Author deactivated
SELECT id, filtername, authorname, reqcontent 
	FROM searchrequest WHERE id 
	NOT IN (SELECT entityid FROM sharepermissions WHERE entitytype = 'SearchRequest');

SELECT sr.id, sr.filtername, cu.user_name, sr.reqcontent
	FROM searchrequest sr
	JOIN app_user au ON sr.authorname = au.user_key
	JOIN cwd_user cu ON au.lower_user_name = cu.lower_user_name
	LEFT JOIN sharepermissions sp ON sr.id = sp.entityid AND sp.entitytype = 'SearchRequest'
	WHERE cu.active = 0 AND sp.entityid IS NULL;

--Jira filters owned by invalid users
--https://support.atlassian.com/portfolio-insights/docs/jira-filters-owned-by-invalid-users/

SELECT DISTINCT sr.filtername AS "Filter name",
sr.username AS "Filter username",
sr.authorname AS "Filter author",
cwu.lower_email_address AS "Filter inactive user email address",
cwu.display_name AS "Filter inactive user display name",
au.user_key AS "Filter inactive user user key",
CASE WHEN cwu.active = 0 THEN 'Inactive' ELSE 'Active' END AS "User status",
sr.reqcontent AS "Filter JQL"
FROM cwd_user cwu
INNER JOIN app_user au ON (cwu.lower_user_name = au.lower_user_name)
JOIN searchrequest sr ON ((sr.username = cwu.lower_user_name OR sr.username = au.user_key)
OR (sr.authorname = cwu.lower_user_name OR sr.authorname = au.user_key))
WHERE cwu.active = 0;



--Critical Data Center Warning
	--Do not directly DELETE via SQL: This causes index desynchronization and breaks system integrity.
	--Safe Cleanup: Export the list of filter_id values and use the Administration > System > Shared Items > Filters UI to reassign or delete filters safely.

--Project does not exist

--Query or ways to find filters which linked with any dashboard or board
--https://community.atlassian.com/forums/Jira-questions/Query-or-ways-to-find-filters-which-linked-with-any-dashboard-or/qaq-p/1064874
--This returns the board name's and id numbers along with the filter names and other filter details:
select "AO_60DB71_RAPIDVIEW"."NAME" as BoardName, "AO_60DB71_RAPIDVIEW"."ID" as BoardID, sr.* 
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



