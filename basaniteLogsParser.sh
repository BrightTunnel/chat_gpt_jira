#!/bin/bash
#--Atlassian Application Failure Root Cause Analyzer. Scans local application node logs for fatal error patterns.
#--SeismoLog by Valeri Tikhonov, TD, May 2026.

REPORTS="/media/user/Storage/lenovo-storage/@Mobile/@Wiki/Projects/@Java/@Jira/temp_collection_of_scripts_to_be_sorted/bash/tmp/seismo_FailureRCAnalysis_$(date +%Y%m%d-%H%M%S)/"
mkdir -p "${REPORTS}"
SeismoRCAReportLog="${REPORTS}sseismo_failure-analysis.log"
SeismoLogExcerpt="${REPORTS}seismo_log_excerpt.log"


#bash << 'EOF'
set enable-bracketed-paste on
{
#SeismoRCAReportLog="sseismo_failure-analysis.log"
#SeismoLogExcerpt="seismo_log_excerpt.log"
RangeTopDate="2026-02-10"; RangeTopTime="00:00"
RangeEndDate="2026-05-07"; RangeEndTime="23:59"
XcrptTopDate="2026-03-13"; XcrptTopTime="10:37"
XcrptEndDate="2026-05-07"; XcrptEndTime="10:38"
SensitivitySys=5
SensitivityHome=20
choice="DBG"
#choice="CONF"
#choice="JIRA"
if [[ "$choice" == "JIRA" ]]; then
    APP_INST="/opt/atlassian/jira/install/logs/"
	APP_HOME="/opt/atlassian/jira/home/log/"
	CATALINA_LOG="${APP_INST}catalina." #catalina.2026-03-14.log
	APP_MAIN_LOG="${APP_HOME}atlassian-jira-perf.log"
	APP_MAIN_LOG="${APP_HOME}atlassian-jira.log"
elif [[ "$choice" == "CONF" ]]; then
    APP_INST="/opt/atlassian/confluence/install/logs/"
    APP_HOME="/opt/atlassian/confluence/home/logs/"
    CATALINA_LOG="${APP_INST}catalina."
    APP_MAIN_LOG="${APP_HOME}atlassian-confluence.log"
elif [[ "$choice" == "Bitbucket" ]]; then
    exit
elif [[ "$choice" == "DBG" ]]; then    
	APP_INST="${1:-/media/user/Storage/@jira_logs_copy/jira_sys/logs/}"
	APP_HOME="${2:-/media/user/Storage/@jira_logs_copy/jira_home/log/}"
	CATALINA_LOG=${2:-/home/user/atlassian-jira-software/logs/catalina.out}
	CATALINA_LOG="${APP_INST}catalina."
	APP_MAIN_LOG=${1:-/home/user/atlassian-jira-home/log/atlassian-jira.log}
	APP_MAIN_LOG="${APP_HOME}atlassian-jira.log"
fi
ExcerptOriginFileName=${APP_MAIN_LOG}
#catalinaLogName="${CATALINA_LOG##*/}"
#appLogName="${APP_MAIN_LOG##*/}"

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

LeadingIsoDateRegex="^[0-9]{4}-[0-9]{2}-[0-9]{2}"
convert_string_date_to_iso() {
	formatted_date=$(date -d "$1" +%F 2>/dev/null) || formatted_date="1970-01-01"
	echo "$formatted_date"
}
print_seismograph() {
	local scale=${1:-10}
	local threshold=${2:-1}
	shift; shift #shift arguments so "$@" contains only data
	awk -v s="$scale" -v t="$threshold" '$1 > t { printf "%s %s  %s ", $2, $3, $1; for(i=0; i<$1/s; i++) printf "*"; print "" }' "$@"
}
date_range_full() {
	awk -v start="$RangeTopDate $RangeTopTime" -v end="$RangeEndDate $RangeEndTime" '$1 " " $2 >= start && $1 " " $2 <= end' "$@"
}
date_range_excerpt() {
	awk -v start="$XcrptTopDate $XcrptTopTime" -v end="$XcrptEndDate $XcrptEndTime" '$1 " " $2 >= start && $1 " " $2 <= end' "$@"
}
#--SYS TOMCAT INSTALL_LOG
RollingDay=${RangeTopDate}
LogNames="" 
LogsParsedInfo=""
EndComparison=$(date -d "${RangeEndDate} + 1 day" +%Y-%m-%d)
while [ "${RollingDay}" != "$EndComparison" ]; do
	LogFile="${CATALINA_LOG}${RollingDay}.log"
	if [[ -f "$LogFile" ]]; then
		#echo "Found: $LogFile"
		LogNames+=" $LogFile"
		LogsParsedInfo+="\n${LogFile}"
		echo "~Add to scope ${LogFile}" #Debug/Verbose
	#else echo "Missing: $LogFile" >&2
	fi
	RollingDay=$(date -d "${RollingDay} + 1 day" +%Y-%m-%d)
done
echo "~Parsing SYS logs..." #Debug/Verbose
echo -e "~INSTALL logs in range from ${RangeTopDate} ${RangeTopTime} to ${RangeEndDate} ${RangeEndTime}:${LogsParsedInfo}" > ${SeismoRCAReportLog}
if [[ -n "$LogNames" ]]; then
	echo "~Events: ${FilterOR}" >> "${SeismoRCAReportLog}"
	echo "~SeismoGraph:" >> "${SeismoRCAReportLog}"
	LeadingDateRegex="^[0-9]{2}-[A-Z][a-z]{2}-[0-9]{4}"
	grep -Eh "${LeadingDateRegex}" ${LogNames} | while read -r date_str time_str rest; do
		iso_date=$(convert_string_date_to_iso "${date_str}")
		echo "${iso_date} ${time_str} ${rest}"
		done | date_range_full | grep -E ${FilterOR} | sort | cut -c 1-16 | uniq -c | print_seismograph 1 "$SensitivitySys" >> ${SeismoRCAReportLog} 
else
	echo "~SeismoGraph~ No INSTALL_LOG data found." >> ${SeismoRCAReportLog}
fi

#--HOME_LOG
LogNamesArr=("${APP_MAIN_LOG}")
LogNames="${LogNamesArr[0]}"
for ((i=1; i<11; i++)); do
	if [[ -f "${APP_MAIN_LOG}.${i}" ]]; then
		LogNamesArr+=("${APP_MAIN_LOG}.${i}")
		#--Conat log files. Separate file names by space
		LogNames+=" ${LogNamesArr[i]}"
		echo "~Add to scope ${LogNamesArr[i]}" #Debug/Verbose
	#else #echo "Warning: file ${APP_MAIN_LOG}.${i} not found" >&2
	fi
done
echo "~Parsing HOME logs..." #Debug/Verbose
if [[ "${#LogNamesArr[@]}" -gt 1 ]]; then
	echo >> ${SeismoRCAReportLog}
	echo -e "~HOME logs in range from ${RangeTopDate} ${RangeTopTime} to ${RangeEndDate} ${RangeEndTime}:\n${LogNames// /\\n}" >> ${SeismoRCAReportLog}
	echo "~Events: ${FilterOR}" >> ${SeismoRCAReportLog}
	echo "~SeismoGraph:" >> ${SeismoRCAReportLog}
	grep -Eh ${LeadingIsoDateRegex} ${LogNames} | date_range_full | grep -E ${FilterOR} | sort | cut -c 1-16 | uniq -c | print_seismograph 10 "$SensitivityHome" >> ${SeismoRCAReportLog}
else
	echo "~SeismoGraph~ No HOME_LOG found." >> ${SeismoRCAReportLog}
fi

#-HOME_LOG_NARROW_EXCERPT
echo "~Extracting Excerpt from the: ${ExcerptOriginFileName}..." #Debug/Verbose
echo -e "~HOME logs NARROW_EXCERPT in range from ${XcrptTopDate} ${XcrptTopTime} to ${XcrptEndDate} ${XcrptEndTime}:\n${ExcerptOriginFileName// /\\n}" > ${SeismoLogExcerpt}
echo "" >> ${SeismoLogExcerpt}
grep -Eh ${LeadingIsoDateRegex} ${ExcerptOriginFileName} | date_range_excerpt | sed 'G' >> "${SeismoLogExcerpt}"

echo "~SeismoGraph: Logs scan complete."
echo "~SeismoGraph: eof" >> ${SeismoRCAReportLog}

}
#EOF
#====================
#====================
exit 0

