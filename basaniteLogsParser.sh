#!/bin/bash
#--Atlassian Application Failure Root Cause Analyzer. Scans local application node logs for fatal error patterns.
#--SeismoLog by Valeri Tikhonov, TD, May 2026.



#bash << 'EOF'
set enable-bracketed-paste on
{
choice="DBG"
#choice="CONF"
#choice="JIRA"
SeismoRCAReportLog="sseismo_failure-analysis.log"
SeismoLogExcerpt="seismo_log_excerpt.log"
if [[ "$choice" == "JIRA" ]]; then
	APP_INST="/opt/atlassian/jira/install/logs/"
	APP_HOME="/opt/atlassian/jira/home/log/"
	CATALINA_LOG="${APP_INST}catalina." #catalina.2026-03-14.log
	APP_MAIN_LOG="${APP_HOME}atlassian-jira-perf.log"
	APP_MAIN_LOG="${APP_HOME}atlassian-jira.log"
	thresholdSys=5
	thresholdHome=20
elif [[ "$choice" == "CONF" ]]; then
	APP_INST="/opt/atlassian/confluence/install/logs/"
	APP_HOME="/opt/atlassian/confluence/home/logs/"
	CATALINA_LOG="${APP_INST}catalina."
	APP_MAIN_LOG="${APP_HOME}atlassian-confluence.log"
	thresholdSys=5
	thresholdHome=20
elif [[ "$choice" == "Bitbucket" ]]; then
	exit
elif [[ "$choice" == "DBG" ]]; then
	APP_INST="/media/user/Storage/@jira_logs_copy/jira_sys/logs/"
	APP_HOME="/media/user/Storage/@jira_logs_copy/jira_home/log/"
	CATALINA_LOG=${2:-/home/user/atlassian-jira-software/logs/catalina.out}
	CATALINA_LOG="${APP_INST}catalina."
	APP_MAIN_LOG=${1:-/home/user/atlassian-jira-home/log/atlassian-jira.log}
	APP_MAIN_LOG="${APP_HOME}atlassian-jira.log"
	thresholdSys=1
	thresholdHome=1
	REPORTS="/media/user/Storage/lenovo-storage/@Mobile/@Wiki/Projects/@Java/@Jira/temp_collection_of_scripts_to_be_sorted/bash/tmp/seismo_FailureRCAnalysis_$(date +%Y%m%d-%H%M%S)/"
	mkdir -p "${REPORTS}"
	SeismoRCAReportLog="${REPORTS}sseismo_failure-analysis.log"
	SeismoLogExcerpt="${REPORTS}seismo_log_excerpt.log"
fi
#catalinaLogName="${CATALINA_LOG##*/}"
#appLogName="${APP_MAIN_LOG##*/}"

RangeHeadDate="2026-02-11"; RangeHeadTime="11:11"
RangeTailDate="2026-02-15"; RangeTailTime="23:10"
XcrptHeadDateTime="2026-03-08 16:33"
XcrptTailDateTime="2026-03-08 16:35"
XcrptFromTheLog="${APP_HOME}atlassian-jira.log.1 ${APP_HOME}atlassian-jira.log.2"

RangeHeadEpoch=$(date -d "${RangeHeadDate} ${RangeHeadTime}" +%s)
RangeTailEpoch=$(date -d "${RangeTailDate} ${RangeTailTime}" +%s)
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
#FilterOR+="|WARN|INFO" #Debug/Verbose

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
	awk -v start="$RangeHeadDate $RangeHeadTime" -v end="$RangeTailDate $RangeTailTime" '$1 " " $2 >= start && $1 " " $2 <= end' "$@"
}
date_range_excerpt() {
	awk -v start="$XcrptHeadDateTime" -v end="$XcrptTailDateTime" '$1 " " $2 >= start && $1 " " $2 <= end' "$@"
}
#--SYS TOMCAT INSTALL_LOG
echo "~Find SYS logs in the range: ${RangeHeadDate}..${RangeTailDate}" #Debug/Verbose
RollingDay=${RangeHeadDate}
LogNames="" 
LogsParsedInfo=""
EndComparison=$(date -d "${RangeTailDate} + 1 day" +%Y-%m-%d)
while [ "${RollingDay}" != "$EndComparison" ]; do
	LogFile="${CATALINA_LOG}${RollingDay}.log"
	if [[ -f "$LogFile" ]]; then
		#echo "Found: $LogFile"
		LogNames+=" $LogFile"
		LogsParsedInfo+="\n${LogFile}"
		echo "${LogFile}" #Debug/Verbose
	#else echo "Missing: $LogFile" >&2
	fi
	RollingDay=$(date -d "${RollingDay} + 1 day" +%Y-%m-%d)
done
echo "~Parsing SYS logs..." #Debug/Verbose
if [[ -n "$LogNames" ]]; then
	echo -e "~INSTALL logs in range from ${RangeHeadDate} ${RangeHeadTime} to ${RangeTailDate} ${RangeTailTime}:${LogsParsedInfo}" > ${SeismoRCAReportLog}
	echo "~Events: ${FilterOR}" >> "${SeismoRCAReportLog}"
	echo "~SeismoGraph:" >> "${SeismoRCAReportLog}"
	LeadingDateRegex="^[0-9]{2}-[A-Z][a-z]{2}-[0-9]{4}"
	grep -Eh "${LeadingDateRegex}" ${LogNames} | while read -r date_str time_str rest; do
		iso_date=$(convert_string_date_to_iso "${date_str}")
		echo "${iso_date} ${time_str} ${rest}"
		done | date_range_full | grep -E ${FilterOR} | sort | cut -c 1-16 | uniq -c | print_seismograph 1 "$thresholdSys" >> ${SeismoRCAReportLog} 
else
	echo "~SeismoGraph~ No INSTALL_LOG data found." >> ${SeismoRCAReportLog}
fi

#--HOME_LOG
echo "~Find HOME logs in the range: ${RangeHeadDate}..${RangeTailDate}" #Debug/Verbose
LogNames=""
LogNamesArr=()
is_range_found=0
for ((i=0; i<16; i++)); do
	nextLogName=${APP_MAIN_LOG}
	if [[ i -gt 0 ]]; then
		nextLogName+=".${i}"
	fi	
	if [[ -f "${nextLogName}" ]]; then
		#Check if log file contains target dates range. Get first and last timestamp from file
		FIRST_LINE=$(head -n 100 "${nextLogName}" | grep -m 1 "^[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}" | awk '{print $1,$2}' | cut -d',' -f1)
		LAST_LINE=$(tac "${nextLogName}" | grep -m 1 "^[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}" | awk '{print $1,$2}' | cut -d',' -f1)
		firstLineEpoch=$(date -d "$FIRST_LINE" +%s 2>/dev/null)
		lastLineEpoch=$(date -d "$LAST_LINE" +%s 2>/dev/null)
		#Check if dates fall within this file's range
		if [[ ($firstLineEpoch -ge $RangeHeadEpoch && $firstLineEpoch -le $RangeTailEpoch) || ($lastLineEpoch -ge $RangeHeadEpoch && $lastLineEpoch -le $RangeTailEpoch) ||
			($RangeHeadEpoch -ge $firstLineEpoch && $RangeHeadEpoch -le $lastLineEpoch) || ($RangeTailEpoch -ge $firstLineEpoch && $RangeTailEpoch -le $lastLineEpoch) ]]; then
			is_range_found=1
			LogNamesArr+=(${nextLogName})
			#Conat log file names, separate file names by space
			if [ -n "$LogNames" ]; then
				LogNames+=" "
			fi
			LogNames+="${nextLogName}"
			echo "InTheRange: ${nextLogName}* ${FIRST_LINE}..${LAST_LINE} " #Debug/Verbose
		elif [[ ${is_range_found} -eq 1 ]]; then
			echo "OutOfRange: ${nextLogName}  ${FIRST_LINE}..${LAST_LINE}" #Debug/Verbose
			#break
		else
			echo "NotInRgYet: ${nextLogName}  ${FIRST_LINE}..${LAST_LINE}" #Debug/Verbose
		fi
	else 
		echo "FileNotFnd: ${nextLogName}" #Debug/Verbose
	fi
done
echo "~Parsing HOME logs..." #Debug/Verbose
if [[ "${#LogNamesArr[@]}" -gt 0 ]]; then
	echo >> ${SeismoRCAReportLog}
	echo -e "~HOME logs in range from ${RangeHeadDate} ${RangeHeadTime} to ${RangeTailDate} ${RangeTailTime}:\n${LogNames// /\\n}" >> ${SeismoRCAReportLog}
	echo "~Events: ${FilterOR}" >> ${SeismoRCAReportLog}
	echo "~SeismoGraph:" >> ${SeismoRCAReportLog}
	grep -Eh ${LeadingIsoDateRegex} ${LogNames} | date_range_full | grep -E ${FilterOR} | sort | cut -c 1-16 | uniq -c | print_seismograph 10 "$thresholdHome" >> ${SeismoRCAReportLog}
else
	echo "~SeismoGraph~ No HOME_LOG found." >> ${SeismoRCAReportLog}
fi


exit 0
#-HOME_LOG_NARROW_EXCERPT
echo "~Extracting Excerpt from the: ${XcrptFromTheLog}..." #Debug/Verbose
echo -e "~HOME logs NARROW_EXCERPT in range from ${XcrptHeadDateTime} to ${XcrptTailDateTime}:\n${XcrptFromTheLog// /\\n}" > ${SeismoLogExcerpt}
echo "" >> ${SeismoLogExcerpt}
grep -Eh ${LeadingIsoDateRegex} ${XcrptFromTheLog} | date_range_excerpt | sed 'G' >> "${SeismoLogExcerpt}"

echo "~SeismoGraph: Logs scan complete."
echo "~SeismoGraph: eof" >> ${SeismoRCAReportLog}

}
#EOF
#====================
#====================

