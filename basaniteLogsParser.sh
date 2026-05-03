bash << 'EOF'
APP_INST="/opt/atlassian/confluence/install/logs/"
APP_HOME="/opt/atlassian/confluence/home/logs/"
CATALINA_LOG="${APP_INST}catalina."
APP_MAIN_LOG="${APP_HOME}atlassian-confluence.log"
SeismoRCAReportLog="seismoRCAReport.log"
SeismoLogExcerpt="seismoLogExcerpt.log"
declare -A keywordsMap
keywordsMap["Atlassian-errors"]="[[:space:]](ERROR|FATAL|SEVERE|CRITICAL)[[:space:]]"
keywordsMap["Exceptions"]="[A-Za-z0-9\.]+Exception"
keywordsMap["SlowRESTRequests"]="Request.*took"
keywordsMap["Cluster-health"]="Cluster.*lost|node.*not[[:space:]]responding|heartbeat|split[[:space:]]brain"
keywordsMap["JvmOutOfMemory"]="OutOfMemoryError" 
keywordsMap["DatabaseFailures"]="connection.*fail|database.*down|PSQLException|SQLTransientConnectionException"
keywordsMap["PluginFailures"]="Plugin.*failed|Unable[[:space:]]to[[:space:]]start[[:space:]]plugin|OSGi|Spring[[:space:]]context[[:space:]]failed"
keywordsMap["ThreadPoolStarvation"]="Thread.*blocked|StuckThread|thread[[:space:]]starvation"
keywordsMap["ThreadPoolExecutor"]="max[[:space:]]threads|busy[[:space:]]threads|stuck[[:space:]]thread"
FilterOR="StuckThreadDetected"
FilterOR+="|memory[[:space:]]leak"
FilterOR+="|may[[:space:]]be[[:space:]]stuck"
FilterOR+="|has[[:space:]]failed"
FilterOR+="|${keywordsMap["Atlassian-errors"]}"
FilterOR+="|${keywordsMap["Exceptions"]}"
FilterOR+="|${keywordsMap["SlowRESTRequests"]}"
FilterOR+="|${keywordsMap["Cluster-health"]}"
FilterOR+="|${keywordsMap["JvmOutOfMemory"]}"
FilterOR+="|${keywordsMap["DatabaseFailures"]}"
FilterOR+="|${keywordsMap["PluginFailures"]}"
FilterOR+="|${keywordsMap["ThreadPoolStarvation"]}"
FilterOR+="|${keywordsMap["ThreadPoolExecutor"]}"
StartDate="2026-02-10"; StartTime="00:00"
EndDate="2026-02-18"; EndTime="23:59"

convert_string_date_to_iso() {
	local default_date="1970-01-01"
	if [[ -z "$1" ]]; then
		echo "$default_date"
		return
	fi
	date -d "$1" +%F 2>/dev/null || echo "$default_date"
}
print_seismograph() {
	local scale=${1:-10} 
	shift 
	awk -v s="$scale" '{ printf "%s %s   %s ", $2, $3, $1; for(i=0; i<$1/s; i++) printf "*"; print "" }' "$@"
}
date_range() {
	awk -v start="$StartDate $StartTime" -v end="$EndDate $EndTime" '$1 " " $2 >= start && $1 " " $2 <= end'  "$@"
}

RollingDay=${StartDate}
LogNames="" 
LogsParsedInfo=""
EndComparison=$(date -d "${EndDate} + 1 day" +%Y-%m-%d)
while [ "${RollingDay}" != "$EndComparison" ]; do
	LogFile="${CATALINA_LOG}${RollingDay}.log"
	if [[ -f "$LogFile" ]]; then
		LogNames+=" $LogFile"
		LogsParsedInfo+="\n${LogFile}"
	fi
	RollingDay=$(date -d "${RollingDay} + 1 day" +%Y-%m-%d)
done
echo >> ${SeismoRCAReportLog}
echo -e "~INSTALL logs in range from ${StartDate} ${StartTime} to ${EndDate} ${EndTime}:${LogsParsedInfo}" >> ${SeismoRCAReportLog}
if [[ -n "$LogNames" ]]; then
	echo "~Events: ${FilterOR}" >> "${SeismoRCAReportLog}"
	echo "~SeismoGraph:" >> "${SeismoRCAReportLog}"
	LeadingDateRegex="^[0-9]{2}-[A-Z][a-z]{2}-[0-9]{4}"
	printf "*"; print ""}' >> ${SeismoRCAReportLog}

	grep -Eh "${LeadingDateRegex}" ${LogNames} | while read -r date_str time_str rest; do
   		iso_date=$(convert_string_date_to_iso "${date_str}")
		echo "${iso_date} ${time_str} ${rest}"
		done | date_range | grep -E ${FilterOR} | sort | cut -c 1-16 | uniq -c | print_seismograph 1 >> ${SeismoRCAReportLog} 
else
	echo "~SeismoGraph~ No INSTALL_LOG data found." >> ${SeismoRCAReportLog}
fi

LogNamesArr=("${APP_MAIN_LOG}")
LogNames="${LogNamesArr[0]}"
for ((i=1; i<11; i++)); do
	if [[ -f "${APP_MAIN_LOG}.${i}" ]]; then
		LogNamesArr+=("${APP_MAIN_LOG}.${i}")
		LogNames+=" ${LogNamesArr[i]}"
	fi
done
if [[ "${#LogNamesArr[@]}" -gt 1 ]]; then
	echo >> ${SeismoRCAReportLog}
	echo -e "~HOME logs in range from ${StartDate} ${StartTime} to ${EndDate} ${EndTime}:\n${LogNames// /\\n}" >> ${SeismoRCAReportLog}
	echo "~Events: ${FilterOR}" >> ${SeismoRCAReportLog}
	echo "~SeismoGraph:" >> ${SeismoRCAReportLog}
	LeadingIsoDateRegex="^[0-9]{4}-[0-9]{2}-[0-9]{2}"
	grep -Eh ${LeadingIsoDateRegex} ${LogNames} | date_range | grep -E ${FilterOR} | sort | cut -c 1-16 | uniq -c | print_seismograph 20 >> ${SeismoRCAReportLog}
else
	echo "~SeismoGraph~ No HOME_LOG found." >> ${SeismoRCAReportLog}
fi
EOF

#StartDate="2026-02-15"; StartTime="21:47"
#EndDate="2026-02-15"; EndTime="22:09"
#echo -e "~HOME logs NARROW_EXCERPT in range from ${StartDate} ${StartTime} to ${EndDate} ${EndTime}:\n${LogNames// /\\n}" >> ${SeismoLogExcerpt}
#echo >> ${SeismoLogExcerpt}
#grep -Eh ${LeadingIsoDateRegex} ${LogNames} | date_range | sed 'G' >> "${SeismoLogExcerpt}"
#echo "~SeismoGraph: Log scan complete." >> ${SeismoRCAReportLog}
