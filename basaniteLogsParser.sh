
#--Used Tables:
select * from "AO_60DB71_RAPIDVIEW"; #--AO_60DB71 "Jira Agile" com.pyxis.greenhoper.jira, Atlassian, V.10.3.8
select * from "searchrequest";

SELECT --Anthony 
	rv."ID" AS board_id,
	rv."NAME" AS board_name,
	--rv."RAPID_VIEW_TYPE" AS board_type,
	rv."SAVED_FILTER_ID" AS filter_id,
	sr.filtername AS filter_name,
	sr.authorname AS filter_owner,
	sr.reqcontent AS filter_jql,
	CASE WHEN sr.reqcontent LIKE '%project =%' OR sr.reqcontent LIKE '%project in (%' THEN 'Scoped' ELSE 'Unscoped/Unknown' END AS project_scope_flag, 
	CASE WHEN sr.reqcontent LIKE '%text ~%' THEN 'Y' ELSE 'N' END AS text_search,
	CASE WHEN sr.reqcontent LIKE '%summary ~%' THEN 'Y' ELSE 'N' END AS summary_search,
	CASE WHEN sr.reqcontent LIKE '%description ~%' THEN 'Y' ELSE 'N' END AS description_search,
	CASE WHEN sr.reqcontent LIKE '%comment ~%' THEN 'Y' ELSE 'N' END AS comment_search,
	CASE WHEN sr.reqcontent LIKE '%issueFunction%' THEN 'Y' ELSE 'N' END AS script_runner_fn,
	CASE WHEN sr.reqcontent LIKE '%ORDER BY updated DESC%' THEN 'Y' ELSE 'N' END AS updated_sort,
	CASE WHEN sr.reqcontent LIKE '%filter =%' THEN 'Y' ELSE 'N' END AS nested_filter,
	CASE WHEN (
			sr.reqcontent LIKE '%text ~%' OR
			sr.reqcontent LIKE '%summary ~%' OR
			sr.reqcontent LIKE '%description ~%' OR 
			sr.reqcontent LIKE '%comment ~%' OR
			sr.reqcontent LIKE '%issueFunction%')
			AND NOT (sr.reqcontent LIKE '%project =%' OR sr.reqcontent LIKE '%project in (%')
			THEN 'High'
			WHEN NOT (sr.reqcontent LIKE '%project =%' OR sr.reqcontent LIKE '%project in (%')
			THEN 'Medium'
			ELSE 'Low'
		END AS jql_risk_level
	FROM "AO_60DB71_RAPIDVIEW" as rv
	LEFT JOIN searchrequest sr ON rv."SAVED_FILTER_ID" = sr.id
	ORDER BY 
		CASE WHEN (
			sr.reqcontent LIKE '%text ~%' OR 
			sr.reqcontent LIKE '%summary ~%' OR
			sr.reqcontent LIKE '%description ~%' OR 
			sr.reqcontent LIKE '%comment ~%' OR 
			sr.reqcontent LIKE '%issueFunction%')
			AND NOT (sr.reqcontent LIKE '%project =%' OR sr.reqcontent LIKE '%project in (%')
		THEN 1
		WHEN NOT (sr.reqcontent LIKE '%project =%' OR sr.reqcontent LIKE '%project in (%')
		THEN 2
		ELSE 3 
END, 
	rv."NAME";

