#!/bin/bash
#--Atlassian Application Failure Root Cause Analyzer. Scans local application node logs for fatal error patterns.
#--SeismoLog by Valeri Tikhonov, TD, May 2026.

#bash << 'EOF'
set enable-bracketed-paste on
{
choice="DBG"
#choice="JIRA"
#choice="CONF"
is_web_log=1
SeismoRCAReportLog="sseismo_failure-analysis.log"
SeismoLogExcerpt="seismo_log_excerpt.log"
if [[ "$choice" == "JIRA" ]]; then
	APP_INST="/opt/atlassian/jira/install/logs/"
	APP_HOME="/opt/atlassian/jira/home/log/"
	CATALINA_LOG="${APP_INST}catalina." #catalina.2026-03-14.log
	CATALINA_LOG="${APP_INST}conf_access_log." #conf_access_log.2026-02-12.log
	APP_MAIN_LOG="${APP_HOME}atlassian-jira-perf.log"
	APP_MAIN_LOG="${APP_HOME}atlassian-jira.log"
	thresholdSys=1
	thresholdHome=20
elif [[ "$choice" == "CONF" ]]; then
	APP_INST="/opt/atlassian/confluence/install/logs/"
	APP_HOME="/opt/atlassian/confluence/home/logs/"
	CATALINA_LOG="${APP_INST}catalina." #catalina.2026-03-14.log
	CATALINA_LOG="${APP_INST}conf_access_log." #conf_access_log.2026-02-12.log
	APP_MAIN_LOG="${APP_HOME}atlassian-confluence.log"
	thresholdSys=1
	thresholdHome=20
elif [[ "$choice" == "Bitbucket" ]]; then
	exit
elif [[ "$choice" == "DBG" ]]; then
	APP_INST="/media/user/Storage/@jira_logs_copy/jira_sys/logs/"
	APP_HOME="/media/user/Storage/@jira_logs_copy/jira_home/log/"
	CATALINA_LOG=${2:-/home/user/atlassian-jira-software/logs/catalina.out}
	CATALINA_LOG="${APP_INST}catalina."
	CATALINA_LOG="${APP_INST}conf_access_log." #conf_access_log.2026-02-12.log
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


RangeHeadDate="2026-02-14"; RangeHeadTime="00:00"
RangeTailDate="2026-02-14"; RangeTailTime="23:59"
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
#--Logs: [access_log.2026-05-12, conf_access_log.2026-02-12.log]:
FilterOR+="|[[:space:]]HTTP/1.1[[:space:]]3"
FilterOR+="|[[:space:]]HTTP/1.1[[:space:]]4" #E.g: [HTTP/1.1 403]
FilterOR+="|[[:space:]]HTTP/1.1[[:space:]]5"
#--Logs: [atlassian-confluence.log]:
FilterOR+="|Failed[[:space:]]to[[:space:]]delete" #WARN: Failed to delete a remote link

LeadingIsoDateRegex="^[0-9]{4}-[0-9]{2}-[0-9]{2}"
LeadingDateRegexDash="^[0-9]{2}-[A-Z][a-z]{2}-[0-9]{4}" #DD-Mmm-YYYY HH:mm:ss.sss 12-May-2026 09:24:06.999 --Database timestamps, Java/Oracle logs
LeadingDateRegexSlash="^\[[0-9]{2}/[A-Z][a-z]{2}/[0-9]{4}" #[DD/Mon/YYYY:HH:mm:ss --Apache/Nginx web server logs 

convert_java_date_to_iso() {
	#--From: 12-May-2026 09:24:06.999 to 2026-05-12
	#--From: [12/May/2026:09:24:06 -0400] to 2026-05-12
	formatted_date=$(date -d "$1" +%F 2>/dev/null) || formatted_date="1970-01-01"
	echo "$formatted_date"
}

convert_apache_nginx_date_to_iso() {
    # Accept the raw string, e.g., "[12/Feb/2026:08:59:58 -0400]"
    local input_date="$1"
    LC_ALL=C sed -E '
        s|\[?([0-9]{2})/Jan/([0-9]{4}):.*|\2-01-\1|
        s|\[?([0-9]{2})/Feb/([0-9]{4}):.*|\2-02-\1|
        s|\[?([0-9]{2})/Mar/([0-9]{4}):.*|\2-03-\1|
        s|\[?([0-9]{2})/Apr/([0-9]{4}):.*|\2-04-\1|
        s|\[?([0-9]{2})/May/([0-9]{4}):.*|\2-05-\1|
        s|\[?([0-9]{2})/Jun/([0-9]{4}):.*|\2-06-\1|
        s|\[?([0-9]{2})/Jul/([0-9]{4}):.*|\2-07-\1|
        s|\[?([0-9]{2})/Aug/([0-9]{4}):.*|\2-08-\1|
        s|\[?([0-9]{2})/Sep/([0-9]{4}):.*|\2-09-\1|
        s|\[?([0-9]{2})/Oct/([0-9]{4}):.*|\2-10-\1|
        s|\[?([0-9]{2})/Nov/([0-9]{4}):.*|\2-11-\1|
        s|\[?([0-9]{2})/Dec/([0-9]{4}):.*|\2-12-\1|
        #--Fallback if the pattern does not match expected Apache format
        /^[0-9]{4}-[0-9]{2}-[0-9]{2}$/! s/.*/1970-01-01/
    ' <<< "$input_date"
}

print_seismograph() {
	local scale=${1:-10}
	local threshold=${2:-1}
	shift; shift #shift arguments so "$@" contains only data
	awk -v s="$scale" -v t="$threshold" '$1 > t { printf "%s %s\t%s\t", $2, $3, $1; for(i=0; i<$1/s; i++) printf "*"; print "" }' "$@"
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
		LogNames+=" $LogFile"
		LogsParsedInfo+="\n${LogFile}"
		echo "InTheRange: ${LogFile}*" #Debug/Verbose
	else echo "FileNotFnd: $LogFile" >&2
	fi
	RollingDay=$(date -d "${RollingDay} + 1 day" +%Y-%m-%d)
done

echo "~Parsing SYS logs..." #Debug/Verbose
if [[ -n "$LogNames" ]]; then
	echo -e "~INSTALL logs in range from ${RangeHeadDate} ${RangeHeadTime} to ${RangeTailDate} ${RangeTailTime}:${LogsParsedInfo}" > ${SeismoRCAReportLog}
	echo "~Events: ${FilterOR}" >> "${SeismoRCAReportLog}"
	echo "~SeismoGraph:" >> "${SeismoRCAReportLog}"
	if (( is_web_log == 1 )); then
		#--From: [12/Feb/2026:08:59:58 -0400]
		grep -Eh "${LeadingDateRegexSlash}" ${LogNames} | while read -r ts_part1 ts_part2 rest; do
			# ts_part1: [12/Feb/2026:08:59:58
			# ts_part2: -0400]
			iso_date=$(convert_apache_nginx_date_to_iso "${ts_part1} ${ts_part2}")
			log_time="${ts_part1#*:}" #Extract time 08:59:58
			echo "${iso_date} ${log_time} ${rest}"
			done | date_range_full | grep -E ${FilterOR} | sort | cut -c 1-16 | uniq -c | print_seismograph 1 "$thresholdSys" >> ${SeismoRCAReportLog}
		#--Save All found Error lines
		echo -e "\n~SYS logs ERRORS EXCERPT in range from: ${RangeHeadDate} ${RangeHeadTime} to: ${RangeTailDate} ${RangeTailTime}:${LogNames// /\\n}" >> ${SeismoLogExcerpt}
		grep -Eh ${LeadingDateRegexSlash} ${LogNames} | grep -E ${FilterOR} >> ${SeismoLogExcerpt}
	elif (( is_web_log == 2 )); then
		#--From: 12-May-2026 09:24:06.999
		grep -Eh "${LeadingDateRegexDash}" ${LogNames} | while read -r date_str time_str rest; do
			iso_date=$(convert_java_date_to_iso "${date_str}") #--From: 12-May-2026 09:24:06.999 to 2026-05-12
			echo "${iso_date} ${time_str} ${rest}"
			done | date_range_full | grep -E ${FilterOR} | sort | cut -c 1-16 | uniq -c | print_seismograph 1 "$thresholdSys" >> ${SeismoRCAReportLog}
	fi
else
	echo "~SeismoGraph~ No INSTALL_LOG data found." >> ${SeismoRCAReportLog}
fi


#--HOME_LOG
echo "~Find HOME logs in the range: ${RangeHeadDate}..${RangeTailDate}" #Debug/Verbose
LogNames=""
LogNamesArr=()
lstOfHomeLogFiles=""
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
			lstOfHomeLogFiles+="\n${nextLogName} [${FIRST_LINE}..${LAST_LINE}]"
			echo -e "InTheRange: ${nextLogName} *${FIRST_LINE} - ${LAST_LINE}" #Debug/Verbose
		elif [[ ${is_range_found} -eq 1 ]]; then
			echo -e "OutOfRange: ${nextLogName}  ${FIRST_LINE} - ${LAST_LINE}" #Debug/Verbose
			#break
		else
			echo -e "NotInRgYet: ${nextLogName}  ${FIRST_LINE} - ${LAST_LINE}" #Debug/Verbose
		fi
	else 
		echo "FileNotFnd: ${nextLogName}" #Debug/Verbose
	fi
done
echo "~Parsing HOME logs..." #Debug/Verbose
if [[ "${#LogNamesArr[@]}" -gt 0 ]]; then
	echo >> ${SeismoRCAReportLog}
	echo -e "~HOME logs in range from: ${RangeHeadDate} ${RangeHeadTime} to: ${RangeTailDate} ${RangeTailTime}:${lstOfHomeLogFiles}" >> ${SeismoRCAReportLog}
	echo "~Events: ${FilterOR}" >> ${SeismoRCAReportLog}
	echo "~SeismoGraph:" >> ${SeismoRCAReportLog}
	grep -Eh ${LeadingIsoDateRegex} ${LogNames} | date_range_full | grep -E ${FilterOR} | sort | cut -c 1-16 | uniq -c | print_seismograph 10 "$thresholdHome" >> ${SeismoRCAReportLog}
	#--Save All found Error lines
	echo -e "\n~HOME logs ERRORS EXCERPT in range from ${RangeHeadDate} ${RangeHeadTime} to ${RangeTailDate} ${RangeTailTime}:\n${LogNames// /\\n}" >> ${SeismoLogExcerpt}
	grep -Eh ${LeadingIsoDateRegex} ${LogNames} | date_range_full | grep -E ${FilterOR} | sort >> ${SeismoLogExcerpt}
else
	echo "~SeismoGraph~ No HOME_LOG found." >> ${SeismoRCAReportLog}
fi
}
EOF
#======


exit 0
#-HOME_LOG_NARROW_EXCERPT
echo "~Extracting Excerpt from the: ${XcrptFromTheLog}..." #Debug/Verbose
echo -e "~HOME logs NARROW_EXCERPT in range from ${XcrptHeadDateTime} to ${XcrptTailDateTime}:\n${XcrptFromTheLog// /\\n}" > ${SeismoLogExcerpt}
echo "" >> ${SeismoLogExcerpt}
grep -Eh ${LeadingIsoDateRegex} ${XcrptFromTheLog} | date_range_excerpt | sed 'G' >> "${SeismoLogExcerpt}"
echo "~SeismoGraph: Logs scan complete."
echo "~SeismoGraph: eof" >> ${SeismoRCAReportLog}

