#!/bin/bash
#--Jira Node Failure Root Cause Analyzer. Scans jira + catalina logs for fatal patterns
#--Seismo by Valeri Tikhonov, TD, April-May 2026.

#sudo su - user
#rm ${SeismoRCAReportLog}

##--Logs:
APP_INST="/opt/atlassian/jira/install/logs/"
APP_INST="/opt/atlassian/confluence/install/logs/"
APP_INST="${1:-/media/user/Storage/@jira_logs_copy/jira_sys/logs/}"
APP_HOME="/opt/atlassian/jira/home/logs/"
APP_HOME="/opt/atlassian/confluence/home/logs/" #PAT
APP_HOME="${2:-/media/user/Storage/@jira_logs_copy/jira_home/log/}"
JIRA_AUD="${APP_HOME}audit/"
JIRA_JFR="${APP_HOME}jfr/"
CATALINA_LOG=${2:-/home/user/atlassian-jira-software/logs/catalina.out}
CATALINA_LOG="${APP_INST}catalina." #PAT e.g.: catalina.2026-03-14.log
APP_MAIN_LOG=${1:-/home/user/atlassian-jira-home/log/atlassian-jira.log}
APP_MAIN_LOG="${APP_HOME}atlassian-confluence.log" #PAT
APP_MAIN_LOG="${APP_HOME}atlassian-jira-perf.log"
APP_MAIN_LOG="${APP_HOME}atlassian-jira.log"
JIRA_SLOW_JQL="${APP_HOME}atlassian-jira-slow-queries.log"

catalinaLogName="${CATALINA_LOG##*/}"
appLogName="${APP_MAIN_LOG##*/}"
jiraSlowJql="${JIRA_SLOW_JQL##*/}"
REPORTS="/media/user/Storage/lenovo-storage/@Mobile/@Wiki/Projects/@Java/@Jira/temp_collection_of_scripts_to_be_sorted/bash/tmp/seismo_FailureRCAnalysis_$(date +%Y%m%d-%H%M%S)/"
mkdir -p "${REPORTS}"
SeismoRCAReportLog="${REPORTS}seismoRCAReport.log"
SeismoLogExcerpt="${REPORTS}seismoLogExcerpt.log"

#--Notes:
#--	Dont quote: ${LogNames} when used:
#--	${LogsParsedInfo} for report header only, no business logic attached

#--Events to watch:
# Detect request timeout / slow endpoints
# OutOfMemoryError, JVM memory (Heap space) failures

#--Extra:
#declare -A keywordsMapPiped #keywordsMapPiped[""]="" #--Linear Array style
#keywordsMap["NodeShutdownTrigger"]="Shutdown|Stopping[[:space:]]Jira|Jira[[:space:]]is[[:space:]]shutting[[:space:]]down"
#keywordsMap["Slow JQL"]="took[[:space:]][0-9]+[[:space:]]ms|Slow[[:space:]]request"
#FilterOR+="|${keywordsMap["NodeShutdownTrigger"]}"
#FilterOR+="|[[:space:]](WARNING|WARN)[[:space:]]"


#bash << 'EOF'
#APP_INST="/opt/atlassian/confluence/install/logs/"
#APP_HOME="/opt/atlassian/confluence/home/logs/"
#CATALINA_LOG="${APP_INST}catalina."
#APP_MAIN_LOG="${APP_HOME}atlassian-confluence.log"
#SeismoRCAReportLog="seismoRCAReport.log"
#SeismoLogExcerpt="seismoLogExcerpt.log"

RangeStartDate="2026-02-10"; RangeStartTime="00:00"
RangeEndDate="2026-02-18"; RangeEndTime="23:59"
ExcerptStartDate="2026-03-13"; ExcerptStartTime="10:37"
ExcerptEndDate="2026-03-13"; ExcerptEndTime="10:38"
ExcerptOriginFileName=${APP_MAIN_LOG}

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
	#--Use the first argument as the scale, default to 10 if empty
	local scale=${1:-10} 
	#--Shift arguments so "$@" only contains the filenames
	shift 
	awk -v s="$scale" '{ printf "%s %s   %s ", $2, $3, $1; for(i=0; i<$1/s; i++) printf "*"; print "" }' "$@"
	#awk '{printf "%s %s   %s ", $2, $3, $1; for(i=0; i<$1/10; i++) printf "*"; print ""}' "$@"
}
date_range_full() {
	awk -v start="$RangeStartDate $RangeStartTime" -v end="$RangeEndDate $RangeEndTime" '$1 " " $2 >= start && $1 " " $2 <= end'  "$@"
}
date_range_excerpt() {
	awk -v start="$ExcerptStartDate $ExcerptStartTime" -v end="$ExcerptEndDate $ExcerptEndTime" '$1 " " $2 >= start && $1 " " $2 <= end'  "$@"
}
#--SYS TOMCAT INSTALL_LOG
RollingDay=${RangeStartDate}
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
echo -e "~INSTALL logs in range from ${RangeStartDate} ${RangeStartTime} to ${RangeEndDate} ${RangeEndTime}:${LogsParsedInfo}" > ${SeismoRCAReportLog}
if [[ -n "$LogNames" ]]; then
	echo "~Events: ${FilterOR}" >> "${SeismoRCAReportLog}"
	echo "~SeismoGraph:" >> "${SeismoRCAReportLog}"
	LeadingDateRegex="^[0-9]{2}-[A-Z][a-z]{2}-[0-9]{4}"
	#grep -Eh ${LeadingDateRegex} ${LogNames} | awk '$1 " " $2 >= "01-Jan-2026 00:00" && $1 " " $2 <= "30-Apr-2026 00:00"' | grep -E ${FilterOR} | sort | cut -c 1-17 | uniq -c | awk '{printf "%s %s   %s ", $2, $3, $1; for(i=0; i<$1; i++) printf "*"; print ""}' >> ${SeismoRCAReportLog}
	#test: grep -Eh ${LeadingDateRegex} ${LogNames} |grep -E ${FilterOR} | sort | cut -c 1-16 | uniq -c | print_seismograph 1 >> ${SeismoRCAReportLog} >> ${SeismoRCAReportLog}
	#grep -Eh ${LeadingDateRegex} ${LogNames} >> ${SeismoRCAReportLog}

	grep -Eh "${LeadingDateRegex}" ${LogNames} | while read -r date_str time_str rest; do
   		iso_date=$(convert_string_date_to_iso "${date_str}")
		echo "${iso_date} ${time_str} ${rest}"
		done | date_range_full | grep -E ${FilterOR} | sort | cut -c 1-16 | uniq -c | print_seismograph 1 >> ${SeismoRCAReportLog} 
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
	echo -e "~HOME logs in range from ${ExcerptStartDate} ${RangeStartTime} to ${RangeEndDate} ${RangeEndTime}:\n${LogNames// /\\n}" >> ${SeismoRCAReportLog}
	echo "~Events: ${FilterOR}" >> ${SeismoRCAReportLog}
	echo "~SeismoGraph:" >> ${SeismoRCAReportLog}
	grep -Eh ${LeadingIsoDateRegex} ${LogNames} | date_range_full | grep -E ${FilterOR} | sort | cut -c 1-16 | uniq -c | print_seismograph 20 >> ${SeismoRCAReportLog}
else
	echo "~SeismoGraph~ No HOME_LOG found." >> ${SeismoRCAReportLog}
fi

#-HOME_LOG_NARROW_EXCERPT
echo "~Extracting Excerpt from the: ${ExcerptOriginFileName}..." #Debug/Verbose
echo -e "~HOME logs NARROW_EXCERPT in range from ${ExcerptStartDate} ${ExcerptStartTime} to ${ExcerptEndDate} ${ExcerptEndTime}:\n${ExcerptOriginFileName// /\\n}" > ${SeismoLogExcerpt}
echo "" >> ${SeismoLogExcerpt}
grep -Eh ${LeadingIsoDateRegex} ${ExcerptOriginFileName} | date_range_excerpt | sed 'G' >> "${SeismoLogExcerpt}"

echo "~SeismoGraph: Logs scan complete."
echo "~SeismoGraph: eof" >> ${SeismoRCAReportLog}

#EOF
#====================
#====================

exit 0
#todo: HTTP/1.1" 200



DateRange="^2026-04-23[[:space:]]15:3[45]"
for keyword in "${!keywordsMap[@]}"; do
	echo -e "\n~~cat: $keyword: ${keywordsMap[$keyword]}" >> $SeismoRCAReportLog #--SubHeader/Filter
	grep -E $DateRange $APP_MAIN_LOG | grep -hE ${keywordsMap[$keyword]} >> $SeismoRCAReportLog
	echo -e "\n~~cat: $keyword: ${keywordsMap[$keyword]}" >> $SeismoRCAReportLog #--SubHeader/Filter
	grep -E $DateRange $CATALINA_LOG | grep -hE ${keywordsMap[$keyword]} >> $SeismoRCAReportLog
done

##--Detect thread explosion, thread growth
echo -e "\n~~cat: ThreadExplosion" >> $SeismoRCAReportLog
grep -E $DateRange $CATALINA_LOG | grep -E "http-nio|http-bio|ThreadPoolExecutor" | grep -E "max[[:space:]]threads|busy[[:space:]]threads|stuck[[:space:]]thread" >> $SeismoRCAReportLog

echo -e "\n~~cat: LoadBalancerHealthCheck" >> $SeismoRCAReportLog
grep -E "healthcheck|status|heartbeat" $APP_MAIN_LOG | grep -E "fail|timeout|unreachable" >> $SeismoRCAReportLog

##--Top exceptions summary
grep -E $DateRange $APP_MAIN_LOG | grep -oE "[A-Za-z0-9\.]+Exception" | sort | uniq -c | sort -nr | head -10 >> "${}SeismoRCAtopExceptions.log"


#--The "Quick Peak"
#--1. extracts the date and time (down to the minute), 
#--2. counts errors per minute, and sorts them so the highest density appears at the top:
#--cut -c 1-16: Clips the first 16 characters of the line (2026-04-29 21:51), this captures the Year-Month-Day Hour:Minute.
#--uniq -c: Groups identical minutes together and counts how many times they appear. Only works if your log file is already in chronological order.
#--sort -n: Sorts the results numerically by the count. The "sharpest" density increase will be at the very bottom of the list.
#grep -E $DateRange $APP_MAIN_LOG | grep -E "[[:space:]]ERROR[[:space:]]" | cut -c 1-16 | uniq -c | sort -nr >> "${}SeismoRCAMostErrorsPerMinute.log"
#--If you want to see the timeline in order but highlight where the jumps happen:
grep -E $DateRange $APP_MAIN_LOG | grep -E "[[:space:]]ERROR[[:space:]]|Exception" | cut -c 1-16 | uniq -c >> "${REPORTS}SeismoRCASpikesList.log"
#--Visualizing with a "Text Bar Chart"
grep -E $DateRange $APP_MAIN_LOG | grep -E "[[:space:]]ERROR[[:space:]]|Exception" | cut -d' ' -f2 | cut -d':' -f1,2 | sort | uniq -c | awk '{printf "%s %s ", $2, $1; for(i=0; i<$1/10; i++) printf "#"; print ""}' >> "${REPORTS}SeismoRCASpikesChart.log"



##--echo "Last 50 ERROR timeline:"
tail -50 $APP_MAIN_LOG > "${REPORTS}SeismoRCAJiraLogTail.txt"
echo "Failure Root Cause Analysys completed. Reports saved to: ${REPORTS}"

