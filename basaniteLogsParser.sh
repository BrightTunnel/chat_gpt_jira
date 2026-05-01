#!/bin/bash
#--Jira Node Failure Root Cause Analyzer. Scans jira + catalina logs for fatal patterns
#--Seismo by Valeri Tikhonov, TD, April 2026.

##--Root Folders
APP_INSTALL="/opt/atlassian/jira/install/logs/" #e.g.:catalina.out
APP_INSTALL="/opt/atlassian/confluence/install/logs/" #PAT
APP_INSTALL="${1:-/media/user/Storage/@jira_logs_copy/jira_sys/logs/}"
APP_HOME="/opt/atlassian/jira/home/logs/" #e.g.:atlassian-confluence.log*
APP_HOME="/opt/atlassian/confluence/home/logs/" #PAT
APP_HOME="${2:-/media/user/Storage/@jira_logs_copy/jira_home/log/}"
JIRA_HOME_AUDIT="${APP_HOME}audit/"
JIRA_HOME_JFR="${APP_HOME}jfr/"
##--Logs:
#APP_MAIN_LOG=${1:-/home/user/atlassian-jira-home/log/atlassian-jira.log}
#CATALINA_LOG=${2:-/home/user/atlassian-jira-software/logs/catalina.out}
CATALINA_LOG="${APP_INSTALL}catalina." #PAT e.g.: catalina.2026-03-14.log
APP_MAIN_LOG="${APP_HOME}atlassian-confluence.log" #PAT
APP_MAIN_LOG="${APP_HOME}atlassian-jira-perf.log"
APP_MAIN_LOG="${APP_HOME}atlassian-jira.log"
JIRA_SLOW_JQL="${APP_HOME}atlassian-jira-slow-queries.log"

#catalinaLogName=$(basename "$CATALINA_LOG")
#appLogName=$(basename "$APP_MAIN_LOG")
catalinaLogName="${CATALINA_LOG##*/}"
appLogName="${APP_MAIN_LOG##*/}"
jiraSlowJql="${JIRA_SLOW_JQL##*/}"

#sudo su - user
#rm ${SeismoRCAReportLog}
REPORTS="/media/user/Storage/lenovo-storage/@Mobile/@Wiki/Projects/@Java/@Jira/temp_collection_of_scripts_to_be_sorted/bash/tmp/seismo_FailureRCAnalysis_$(date +%Y%m%d-%H%M%S)/"
mkdir -p "${REPORTS}"
SeismoRCAReportLog="${REPORTS}seismoRCAReport.log"
SeismoLogExcerpt="${REPORTS}seismoLogExcerpt.log"




##--PAT:
#APP_INSTALL="/opt/atlassian/confluence/install/logs/"
#APP_HOME="/opt/atlassian/confluence/home/logs/"
#CATALINA_LOG="${APP_INSTALL}catalina." #e.g.: catalina.2026-03-14.log
#APP_MAIN_LOG="${APP_HOME}atlassian-confluence.log"
#SeismoRCAReportLog="seismoRCAReport.log"
#SeismoLogExcerpt="seismoLogExcerpt.log"

#declare -A keywordsMapPiped #keywordsMapPiped[""]=""
declare -A keywordsMap
keywordsMap=(["Atlassian-errors"]="[[:space:]]+(ERROR|FATAL|SEVERE|CRITICAL)[[:space:]]+" ["Exceptions"]="[A-Za-z0-9\.]+Exception")
keywordsMap["${appLogName}, Atlassian-errors"]="[[:space:]](ERROR|FATAL|SEVERE|CRITICAL)[[:space:]]"
keywordsMap["${appLogName}, Exceptions"]="[A-Za-z0-9\.]+Exception"
keywordsMap["${appLogName}, SlowRESTRequests"]="Request.*took|Slow[[:space:]]request" # Detect request timeout / slow endpoints
keywordsMap["${jiraSlowJql}, Slow JQL"]="took[[:space:]][0-9]+[[:space:]]ms|Slow[[:space:]]request"
keywordsMap["Cluster-health"]="Cluster.*lost|node.*not[[:space:]]responding|heartbeat|split[[:space:]]brain"
keywordsMap["JvmOutOfMemory"]="OutOfMemoryError" #JVM memory (Heap space) failures 
keywordsMap["DatabaseFailures"]="connection.*fail|database.*down|PSQLException|SQLTransientConnectionException"
keywordsMap["PluginFailures"]="Plugin.*failed|Unable[[:space:]]to[[:space:]]start[[:space:]]plugin|OSGi|Spring[[:space:]]context[[:space:]]failed"
keywordsMap["ThreadPoolStarvation"]="Thread.*blocked|StuckThread|thread[[:space:]]starvation"
keywordsMap["ThreadPoolExecutor"]="max[[:space:]]threads|busy[[:space:]]threads|stuck[[:space:]]thread"
keywordsMap["NodeShutdownTrigger"]="Shutdown|Stopping[[:space:]]Jira|Jira[[:space:]]is[[:space:]]shutting[[:space:]]down"
FilterOR+="StuckThreadDetected"
FilterOR+="|memory[[:space:]]leak"
FilterOR+="|may[[:space:]]be[[:space:]]stuck"
FilterOR+="|has[[:space:]]failed"
FilterOR+="|${keywordsMap["${appLogName}, Atlassian-errors"]}"
FilterOR+="|${keywordsMap["${appLogName}, Exceptions"]}"
FilterOR+="|${keywordsMap["${appLogName}, SlowRESTRequests"]}"
FilterOR+="|${keywordsMap["Cluster-health"]}"
FilterOR+="|${keywordsMap["JvmOutOfMemory"]}"
FilterOR+="|${keywordsMap["DatabaseFailures"]}"
FilterOR+="|${keywordsMap["PluginFailures"]}"
FilterOR+="|${keywordsMap["ThreadPoolStarvation"]}"
FilterOR+="|${keywordsMap["ThreadPoolExecutor"]}"
FilterOR+="|${keywordsMap["NodeShutdownTrigger"]}"
#FilterOR+="|[[:space:]](WARNING|WARN)[[:space:]]"

StartDate="2026-02-10"; StartTime="00:00"
EndDate="2026-02-18"; EndTime="23:59"

convert_string_date_to_iso() {
	local formatted_date="1970-01-01"
    if [[ -z "$1" ]]; then
        echo "$formatted_date"
    else
        local formatted_date
        #if formatted_date=$(date -d "$1" +%Y-%m-%d 2>/dev/null); then #Debian
        #if formatted_date=$(date -d "$1" --iso-8601 2>/dev/null); then #--RHEL8 GNU-specific --iso-8601 for perfect compliance.
        if formatted_date=$(date -d "$1" +%F 2>/dev/null); then # RHEL 8 uses GNU date, which supports -d and --iso-8601 directly
            echo "$formatted_date"
        else
            echo "$formatted_date"
        fi
    fi
}

print_seismograph() {
    local scale=${1:-10} # Use the first argument as the scale, default to 10 if empty
    shift #--Shift arguments so "$@" only contains the filenames
    awk -v s="$scale" '{ printf "%s %s   %s ", $2, $3, $1; for(i=0; i<$1/s; i++) printf "*"; print "" }' "$@"
    #awk '{printf "%s %s   %s ", $2, $3, $1; for(i=0; i<$1/10; i++) printf "*"; print ""}' "$@"
}
date_range() {
	awk -v start="$StartDate $StartTime" -v end="$EndDate $EndTime" '$1 " " $2 >= start && $1 " " $2 <= end'  "$@"
}

##--INSTALL_LOG
RollingDay=${StartDate}
LogNames=""
LogsParsedInfo="" #--for report header only, no business logic attached
EndComparison=$(date -d "${EndDate} + 1 day" +%Y-%m-%d)
while [ "${RollingDay}" != "$EndComparison" ]; do
    LogFile="${CATALINA_LOG}${RollingDay}.log"
    if [[ -f "$LogFile" ]]; then #echo "Found: $LogFile"
        LogNames+=" $LogFile"
        LogsParsedInfo+="\n${LogFile}"
    #else echo "Missing: $LogFile" >&2
    fi
	RollingDay=$(date -d "${RollingDay} + 1 day" +%Y-%m-%d)
done
echo >> ${SeismoRCAReportLog}
echo -e "~INSTALL logs in range from ${StartDate} ${StartTime} to ${EndDate} ${EndTime}:${LogsParsedInfo}" >> ${SeismoRCAReportLog}

if [[ -n "$LogNames" ]]; then
	echo "~Events: ${FilterOR}" >> "${SeismoRCAReportLog}"
	echo "~SeismoGraph:" >> "${SeismoRCAReportLog}"
	LeadingDateRegex="^[0-9]{2}-[A-Z][a-z]{2}-[0-9]{4}" #e.g.: 01-Jan-2026
	#grep -Eh ${LeadingDateRegex} ${LogNames} | awk '$1 " " $2 >= "01-Jan-2026 00:00" && $1 " " $2 <= "30-Apr-2026 00:00"' | grep -E ${FilterOR} | sort | cut -c 1-17 | uniq -c | awk '{printf "%s %s   %s ", $2, $3, $1; for(i=0; i<$1; i++) printf "*"; print ""}' >> ${SeismoRCAReportLog}
	#test: grep -Eh ${LeadingDateRegex} ${LogNames} |grep -E ${FilterOR} | sort | cut -c 1-16 | uniq -c | print_seismograph 1 >> ${SeismoRCAReportLog} >> ${SeismoRCAReportLog}
	#grep -Eh ${LeadingDateRegex} ${LogNames} >> ${SeismoRCAReportLog}
	
	grep -Eh "${LeadingDateRegex}" ${LogNames} | while read -r date_str time_str rest; do
   		iso_date=$(convert_string_date_to_iso "${date_str}")
		echo "${iso_date} ${time_str} ${rest}"
		done | date_range | grep -E ${FilterOR} | sort | cut -c 1-16 | uniq -c | print_seismograph 1 >> ${SeismoRCAReportLog} 
else
	echo "~SeismoGraph~ No INSTALL_LOG data found." >> ${SeismoRCAReportLog}
fi


##--HOME_LOG
LogNamesArr=("${APP_MAIN_LOG}")
LogNames="${LogNamesArr[0]}"
for ((i=1; i<11; i++)); do #--Conat log files
    if [[ -f "${APP_MAIN_LOG}.${i}" ]]; then
	    LogNamesArr+=("${APP_MAIN_LOG}.${i}")
	    LogNames+=" ${LogNamesArr[i]}" #--Add space between file names
    #else #echo "Warning: file ${APP_MAIN_LOG}.${i} not found" >&2
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

#-HOME_LOG_NARROW_EXCERPT
StartDate="2026-02-15"; StartTime="21:47"
EndDate="2026-02-15"; EndTime="22:09"
echo -e "~HOME logs NARROW_EXCERPT in range from ${StartDate} ${StartTime} to ${EndDate} ${EndTime}:\n${LogNames// /\\n}" >> ${SeismoLogExcerpt}
echo >> ${SeismoLogExcerpt}
grep -Eh ${LeadingIsoDateRegex} ${LogNames} | date_range | sed 'G' >> ${SeismoLogExcerpt}

echo "~SeismoGraph: The end of the task." >> ${SeismoRCAReportLog}

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

