#!/bin/bash
#--Atlassian Application Failure Root Cause Analyzer. Scans local application node logs for fatal error patterns.
#--SeismoLog by Valeri Tikhonov, TD, May 2026.

#bash << 'EOF'
set enable-bracketed-paste on
{

start_time=$(date +%s%N) #--start time in nanoseconds
SM_REPORTS_DIR="./seismolog"
if [ ! -d "$SM_REPORTS_DIR" ]; then #Check if the directory does NOT exist
	mkdir -p "$SM_REPORTS_DIR"
fi
dtstamp=$(date +"%Y%m%d_%H%M")
NODE=$(hostname -s)
FileSeismoErrorsDensity="${SM_REPORTS_DIR}/seismoErrorsDensity_${dtstamp}.log"
SeismoSysLogsErrorsExcerpt="${SM_REPORTS_DIR}/seismoSysLogsErrorsExcerpt_${dtstamp}.log"
SeismoHomeLogsErrorsExcerpt="${SM_REPORTS_DIR}/seismoHomeLogsErrorsExcerpt_${dtstamp}.log"
SeismoHomeLogsAllInTimeRange="${SM_REPORTS_DIR}/seismoHomeLogsAllInTimeRange_${dtstamp}.log"
SeismoHomeLogsOrig="${SM_REPORTS_DIR}/SeismoHomeLogsOrig_${NODE}_${dtstamp}.tar.gz"

skipSystemLog=1 #--Skip slow (about 15 minutes) process
isDateIso=1
#choice="JIRA"
#choice="CONF"
choice="JIRA_DBG"
#choice="CONF_DBG"
APP_INST="/media/user/Storage/@jira_logs_copy/jira_sys/logs/" #--Debug@Local
APP_HOME="/media/user/Storage/@jira_logs_copy/jira_home/log/" #--Debug@Local
thresholdSys=1
thresholdHome=1
compressRate=1
anchorPrefix="(GET|PUT|POST) "
keyWord00="${anchorPrefix}\/secure\/EditIssue"
keyWord01="${anchorPrefix}\/secure\/QuickEditIssue"
keyWord02="${anchorPrefix}\/secure\/RapidBoard.jspa" #ViewBoard
keyWord03="${anchorPrefix}\/rest\/api\/2\/search" #rest/api/search
keyWord04="${anchorPrefix}\/rest\/api\/2\/issue" #CreateIssue
keyWord05="UNUSED_EP"
keyWord06="UNUSED_EP"
keyWord07="UNUSED_EP"
keyWord08="UNUSED_EP"
if [[ "$choice" == "JIRA" ]]; then
	APP_INST="/opt/atlassian/jira/install/logs/"
	APP_HOME="/opt/atlassian/jira/home/log/"
	CATALINA_LOG="${APP_INST}catalina." #catalina.2026-05-12.log
	CATALINA_LOG="${APP_INST}access_log." #access_log.2026-05-12
	APP_MAIN_LOG="${APP_HOME}atlassian-jira-perf.log"
	APP_MAIN_LOG="${APP_HOME}atlassian-jira.log"
	thresholdHome=10
	compressRate=10
elif [[ "$choice" == "CONF" ]]; then
	APP_INST="/opt/atlassian/confluence/install/logs/"
	APP_HOME="/opt/atlassian/confluence/home/logs/"
	CATALINA_LOG="${APP_INST}catalina." #catalina.2026-05-12.log
	CATALINA_LOG="${APP_INST}conf_access_log." #conf_access_log.2026-05-12.log
	APP_MAIN_LOG="${APP_HOME}atlassian-confluence.log"
	thresholdHome=10
	compressRate=10
	keyWord00="${anchorPrefix}\/login.action"
	keyWord01="${anchorPrefix}\/pages\/copypage.action"
	keyWord02="${anchorPrefix}\/pages\/viewpage.action"
	keyWord03="${anchorPrefix}\/pages\/createpage.action"
	keyWord04="${anchorPrefix}\/pages\/viewpreviousversions.action"
	keyWord05="${anchorPrefix}\/pages\/listpages.action"
	keyWord06="${anchorPrefix}\/pages\/editpage.action"
	keyWord07="${anchorPrefix}\/pages\/viewpageattachments.action"
	keyWord08="${anchorPrefix}\/rest\/api\/search"
elif [[ "$choice" == "Bitbucket" ]]; then
	exit 0
elif [[ "$choice" == "JIRA_DBG" ]]; then
	CATALINA_LOG="${APP_INST}access_log." # "access_log.2026-05-12"
	APP_MAIN_LOG="${APP_HOME}atlassian-jira.log"
elif [[ "$choice" == "CONF_DBG" ]]; then
	keyWord00="${anchorPrefix}\/login.action"
	keyWord01="${anchorPrefix}\/pages\/copypage.action"
	keyWord02="${anchorPrefix}\/pages\/viewpage.action"
	keyWord03="${anchorPrefix}\/pages\/createpage.action"
	keyWord04="${anchorPrefix}\/pages\/viewpreviousversions.action"
	keyWord05="${anchorPrefix}\/pages\/listpages.action"
	keyWord06="${anchorPrefix}\/pages\/editpage.action"
	keyWord07="${anchorPrefix}\/pages\/viewpageattachments.action"
	keyWord08="${anchorPrefix}\/rest\/api\/search"
	CATALINA_LOG=${2:-/home/user/atlassian-jira-software/logs/catalina.out}
	CATALINA_LOG="${APP_INST}catalina."
	CATALINA_LOG="${APP_INST}conf_access_log." #conf_access_log.2026-05-12.log
	APP_MAIN_LOG=${1:-/home/user/atlassian-jira-home/log/atlassian-jira.log}
	APP_MAIN_LOG="${APP_HOME}atlassian-jira.log"
fi
#catalinaLogName="${CATALINA_LOG##*/}"
#appLogName="${APP_MAIN_LOG##*/}"

RangeHeadDate="2026-03-22"; RangeHeadTime="00:00"
RangeTailDate="2026-07-23"; RangeTailTime="23:59"
XcrptHeadDateTime="2026-03-08 16:33"
XcrptTailDateTime="2026-03-08 16:35"
XcrptFromTheLog="${APP_HOME}atlassian-jira.log ${APP_HOME}atlassian-jira.log.1"

RangeHeadEpoch=$(date -d "${RangeHeadDate} ${RangeHeadTime}" +%s)
RangeTailEpoch=$(date -d "${RangeTailDate} ${RangeTailTime}" +%s)
declare -A keywordsMap
keywordsMap["CatalinaXxx"]="[[:space:]]HTTP/1.1[[:space:]]2|[[:space:]]HTTP/1.1[[:space:]]3|[[:space:]]HTTP/1.1[[:space:]]4" #[HTTP/1.1 403]
keywordsMap["Catalina5xx"]="[[:space:]]HTTP/1.1[[:space:]]5" #[HTTP/1.1 403]
keywordsMap["Log4jLogErrors"]="[[:space:]](ERROR|FATAL|SEVERE|CRITICAL)[[:space:]]"
keywordsMap["Log4jLogExcludeLevels"]="[[:space:]](WARN|INFO|DEBUG|TRACE)[[:space:]]"
keywordsMap["Exceptions"]="[A-Za-z0-9\.]+Exception"
keywordsMap["SlowRESTRequests"]="Request.*took|REQUEST"
keywordsMap["Cluster-health"]="Hazelcast|onClusterPanicEvent|Cluster.*lost|node.*not[[:space:]]responding|heartbeat|split[[:space:]]brain"
keywordsMap["JvmOutOfMemory"]="OutOfMemory|OOM|deadlock|timeout|memory[[:space:]]leak" 
keywordsMap["DatabaseFailures"]="connection.*fail|database.*down|PSQLException|SQLTransientConnectionException|SqlExceptionHelper|executeQuery[[:space:]]Error"
keywordsMap["PluginFailures"]="Plugin.*failed|Unable[[:space:]]to[[:space:]]start[[:space:]]plugin|OSGi|Spring[[:space:]]context[[:space:]]failed"
keywordsMap["ThreadPoolStarvation"]="StuckThreadDetected|Thread.*blocked|StuckThread|thread[[:space:]]starvation|BLOCKED"
keywordsMap["ThreadPoolExecutor"]="max[[:space:]]threads|busy[[:space:]]threads|stuck[[:space:]]thread|may[[:space:]]be[[:space:]]stuck"
keywordsMap["DataBaseConnection"]="Hibernate" # HibernateObjectDao
keywordsMap["SlowJQL"]=""
keywordsMap["Mix"]="has[[:space:]]failed|Failed[[:space:]]to[[:space:]]delete|Uh[[:space:]]oh" #WARN: Failed to delete a remote link
#--Distilled Spam/Noise/Special Filters 
keywordsMap["NoiseCSSErrorListener"]="csskit.antlr4.CSSErrorListener" #--Fixed in new version of DC Confl 
keywordsMap["NoiseClusterTimeout"]="Timeout[[:space:]]while[[:space:]]publishing[[:space:]]event[[:space:]]to[[:space:]]cluster"

FilterDistilledForDots="${keywordsMap["NoiseClusterTimeout"]}"
#FilterLog4jExcludeLevels="$^" #--Uncomment to Allow all Log4j Levels 
FilterLog4jExcludeLevels="${keywordsMap["Log4jLogExcludeLevels"]}" #--Allow all except listed Log4j Levels

FilterHomeBlend="${keywordsMap["Log4jLogErrors"]}"
FilterHomeBlend+="|${keywordsMap["Exceptions"]}"
FilterHomeBlend+="|${keywordsMap["Cluster-health"]}"
FilterHomeBlend+="|${keywordsMap["JvmOutOfMemory"]}"
FilterHomeBlend+="|${keywordsMap["PluginFailures"]}"
FilterHomeBlend+="|${keywordsMap["ThreadPoolStarvation"]}"
FilterHomeBlend+="|${keywordsMap["ThreadPoolExecutor"]}"
FilterHomeBlend+="|${keywordsMap["DataBaseConnection"]}"
FilterHomeBlend+="|${keywordsMap["SlowRESTRequests"]}"
FilterHomeBlend+="|${keywordsMap["DatabaseFailures"]}"
FilterHomeBlend+="|${keywordsMap["Mix"]}"

FilterCatalinaXxx="${keywordsMap["CatalinaXxx"]}"
FilterCatalina5xx="${keywordsMap["Catalina5xx"]}"

LeadingIsoDateRegex="^[0-9]{4}-[0-9]{2}-[0-9]{2}" #YYYY-MM-DD HH:mm:ss
LeadingDateRegexDash="^[0-9]{2}-[A-Z][a-z]{2}-[0-9]{4}" #DD-Mmm-YYYY HH:mm:ss.sss 12-May-2026 09:24:06.999 --Database timestamps, Java/Oracle logs
LeadingDateRegexSlash="\[[0-9]{2}/[A-Z][a-z]{2}/[0-9]{4}" #[DD/Mon/YYYY:HH:mm:ss --Apache/Nginx web server logs


convert_java_date_to_iso() {
	#--DateTime Stamp: 12-May-2026 09:24:06.999 to 2026-05-12
	#--DateTime Stamp: [12/May/2026:09:24:06 -0400] to 2026-05-12
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

print_seismographFullLine() {
	local compression=${1:-10}
	local threshold=${2:-1}
	local dotstyle=${3:-~}
	#local argsCount=$#
	shift;shift;shift #shift arguments so "$@" contains only data
	awk -v s="$compression" -v th="$threshold" -v dt="$dotstyle" '$1 >= $1 { printf "%s_%s %s", $2, $3, $1; for(i=0; i<$1/s; i++) printf dt; print "" }'
}

date_range_full() {
	awk -v start="$RangeHeadDate $RangeHeadTime" -v end="$RangeTailDate $RangeTailTime" '$1 " " $2 >= start && $1 " " $2 <= end' "$@"
}

date_range_excerpt() {
	awk -v start="$XcrptHeadDateTime" -v end="$XcrptTailDateTime" '$1 " " $2 >= start && $1 " " $2 <= end' "$@"
}

if (( skipSystemLog == 0 )); then
	#--SYS TOMCAT INSTALL_LOG. Collect List of the Log Files in range.
	echo "~1.Parse SYS logs in the range: ${RangeHeadDate}..${RangeTailDate}" #Debug/Verbose
	RollingDay=${RangeHeadDate}
	SysLogNames=""
	LogsParsedInfo=""
	EndComparison=$(date -d "${RangeTailDate} + 1 day" +%Y-%m-%d)
	while [ "${RollingDay}" != "$EndComparison" ]; do
		LogFile="${CATALINA_LOG}${RollingDay}"
		if [[ "$choice" == "CONF" || "$choice" == "CONF_DBG" ]]; then
			LogFile+=".log" #-- conf_access_log.2026-05-12.log
		fi
		if [[ -f "$LogFile" ]]; then
			SysLogNames+=" $LogFile"
			LogsParsedInfo+="\n${LogFile}"
			echo "InTheRange: ${LogFile} *" #Debug/Verbose
		else echo "FileNotFnd: $LogFile" >&2
		fi
		RollingDay=$(date -d "${RollingDay} + 1 day" +%Y-%m-%d)
	done
	if [[ -n "$SysLogNames" ]]; then
		echo "SeismoLog Errors Density at $(date '+%Y-%m-%d %H:%M:%S')" > "${FileSeismoErrorsDensity}"
		echo -e "~INSTALL logs in range from ${RangeHeadDate} ${RangeHeadTime} to ${RangeTailDate} ${RangeTailTime}:${LogsParsedInfo}" >> ${FileSeismoErrorsDensity}
		echo "~Chart Legend: [(.) HTTP Errors 2xx,3xx,4xx, (*) HTTP Errors 5xx], Filters detailes:" >> ${FileSeismoErrorsDensity}
		echo " . ${FilterCatalinaXxx}" | sed 's/\[\[:space:\]\]/ /g' >> ${FileSeismoErrorsDensity}
		echo " * ${FilterCatalina5xx}" | sed 's/\[\[:space:\]\]/ /g' >> ${FileSeismoErrorsDensity}
		echo -e "~Errors Counter and Density (errors per min):\n" >> ${FileSeismoErrorsDensity}
		echo -e "xxx 3xx 4xx 5xx ep" >> ${FileSeismoErrorsDensity}
	
		if (( isDateIso == 1 )); then #--DateTime Stamp: [12/Feb/2026:08:59:58 -0400], ts_part1: [12/Feb/2026:08:59:58, ts_part2: -0400]
			grep -Eh "${LeadingDateRegexSlash}" ${SysLogNames} |
			awk -v slch="\\" -v destFile="${FileSeismoErrorsDensity}" \
			-v p0="$keyWord00" \
			-v p1="$keyWord01" \
			-v p2="$keyWord02" \
			-v p3="$keyWord03" \
			-v p4="$keyWord04" \
			-v p5="$keyWord05" \
			-v p6="$keyWord06" \
			-v p7="$keyWord07" \
			-v p8="$keyWord08" '
			BEGIN {
				# Safely initialize the pattern array once at startup
				p[0]=p0; p[1]=p1; p[2]=p2; p[3]=p3; p[4]=p4; p[5]=p5; p[6]=p6; p[7]=p7; p[8]=p8
				logDate = "UNKNOWN_DATE"
			}
			{
				# Extract date using standard string indexing instead of regex arrays
				idx = index($0, "[")
				if (idx > 0) {
					logDate = substr($0, idx + 1, 11)
				}
				has3xx = ($0 ~ /HTTP\/1\.1"?[[:space:]]+3[0-9][0-9]/)
				has4xx = ($0 ~ /HTTP\/1\.1"?[[:space:]]+4[0-9][0-9]/)
				has5xx = ($0 ~ /HTTP\/1\.1"?[[:space:]]+5[0-9][0-9]/)
				for (i=0; i<=8; i++) {
					if ($0 ~ p[i]) {
						c[i]++
						if (has3xx) c_3xx[i]++
						if (has4xx) c_4xx[i]++
						if (has5xx) c_5xx[i]++
					}
				}
				print
			}
			END {
				for (i=0; i<=8; i++) {
					gsub(slch, "", p[i])
					# print logDate"\t"(c[i]+0)"\t"(c_4xx[i]+0)"\t"(c_5xx[i]+0)"\t"p[i] >> destFile
					print (c[i]+0)"\t"(c_3xx[i]+0)"\t"(c_4xx[i]+0)"\t"(c_5xx[i]+0)"\t"p[i] >> destFile
				}
				print "" >> destFile 
			}' > /dev/null
	#		}' | grep -E "${FilterCatalinaXxx}|${FilterCatalina5xx}" |
	#		#--Note: This slow loop builds http response chart. Comment it to speedup parsing.
	#		while read -r ts_part1 ts_part2 rest; do
	#			iso_date=$(convert_apache_nginx_date_to_iso "${ts_part1} ${ts_part2}")
	#			log_time="${ts_part1#*:}" #Extract time 08:59:58
	#			echo "${iso_date} ${log_time} ${rest}"
	#		done | date_range_full | sort | cut -c 1-16 | uniq -c | print_seismographFullLine "${compressRate}" "$thresholdSys" "*" >> "${FileSeismoErrorsDensity}"
	#		#--Move this line up
	#		}' > /dev/null
	
	#--This is possible replacement for the code above. TODO: Separate 300/400/500
	#		CACHE_LogsRecords=$(grep -Eh "${LeadingDateRegexSlash}" ${SysLogNames})
	#		join -a1 -a2 -e "" -o '0,1.2,2.2' \
	#			<(echo "${CACHE_LogsRecords}" | grep -E "${FilterDistilledForDots}" | cut -c 1-16 | uniq -c | print_seismographFullLine "${compressRate}" "$thresholdHome" ".") \
	#			<(echo "${CACHE_LogsRecords}" | grep -E "${FilterHomeBlend}" | cut -c 1-16 | uniq -c | print_seismographFullLine "${compressRate}" "$thresholdHome" "*") |
	#		date_range_full | sort >> "${FileSeismoErrorsDensity}"
	
		elif (( isDateIso == 2 )); then #--DateTime Stamp: 12-May-2026 09:24:06.999
			grep -Eh "${LeadingDateRegexDash}" ${SysLogNames} | grep -E ${FilterCatalinaXxx} | while read -r date_str time_str rest; do
				iso_date=$(convert_java_date_to_iso "${date_str}") 
				echo "${iso_date} ${time_str} ${rest}"
				done | date_range_full | sort | cut -c 1-16 | uniq -c | print_seismographFullLine "${compressRate}" "$thresholdSys" "*" >> ${FileSeismoErrorsDensity}
		fi
		elapsed=$(( ($(date +%s%N) - start_time) / 1000000000 )); min=$(( elapsed / 60 )); sec=$(( elapsed % 60 ))
		echo "~2.Elapsed ${min}:${sec}. Exctract and Save Access Log Error Entries to: " ${SeismoSysLogsErrorsExcerpt}
		#--Exctract and Save Error Lines Only
		echo -e "\n~SYS logs ERRORS EXCERPT in range from: ${RangeHeadDate} ${RangeHeadTime} to: ${RangeTailDate} ${RangeTailTime}:${SysLogNames// /\\n}\n" >> ${SeismoSysLogsErrorsExcerpt}
		grep -Eh ${LeadingDateRegexSlash} ${SysLogNames} | grep -E ${FilterCatalinaXxx} >> ${SeismoSysLogsErrorsExcerpt}
	else
		echo "~No access to INSTALL logs at: ${APP_INST}, or logs in range not found." >> ${FileSeismoErrorsDensity}
	fi
fi #--skipSystemLog

#--HOME_LOG. Collect List of the Log Files in range.
elapsed=$(( ($(date +%s%N) - start_time) / 1000000000 )); min=$(( elapsed / 60 )); sec=$(( elapsed % 60 ))
echo "~3.Elapsed ${min}:${sec}. Find HOME logs in the range: ${RangeHeadDate}..${RangeTailDate}" #Debug/Verbose
HomeLogNames=""
HomeLogNamesArr=()
lstOfHomeLogFiles=""
is_range_found=0
for ((i=0; i<16; i++)); do
	nextLogName=${APP_MAIN_LOG}
	if [[ i -gt 0 ]]; then
		nextLogName+=".${i}"
	fi
	if [[ -f "${nextLogName}" ]]; then
		#--Check if log file contains target dates range. Get first and last timestamp from file
		FIRST_LINE=$(head -n 100 "${nextLogName}" | grep -m 1 "^[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}" | awk '{print $1,$2}' | cut -d',' -f1)
		LAST_LINE=$(tac "${nextLogName}" | grep -m 1 "^[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}" | awk '{print $1,$2}' | cut -d',' -f1)
		firstLineEpoch=$(date -d "$FIRST_LINE" +%s 2>/dev/null)
		lastLineEpoch=$(date -d "$LAST_LINE" +%s 2>/dev/null)
		#timeSpanEpoch=$(( (lastLineEpoch - firstLineEpoch) / 3600 )) #--Rounded Hours, use line below to add decimals
		timeSpanEpoch=$(awk -v last="$lastLineEpoch" -v first="$firstLineEpoch" 'BEGIN {printf "%.1f", (last - first) / 3600}')
		#--Check if dates fall within this file's range
		if [[ ($firstLineEpoch -ge $RangeHeadEpoch && $firstLineEpoch -le $RangeTailEpoch) || ($lastLineEpoch -ge $RangeHeadEpoch && $lastLineEpoch -le $RangeTailEpoch) ||
			($RangeHeadEpoch -ge $firstLineEpoch && $RangeHeadEpoch -le $lastLineEpoch) || ($RangeTailEpoch -ge $firstLineEpoch && $RangeTailEpoch -le $lastLineEpoch) ]]; then
			is_range_found=1
			HomeLogNamesArr+=(${nextLogName})
			#Conat log file names, separate file names by space
			if [ -n "$HomeLogNames" ]; then
				HomeLogNames+=" "
			fi
			HomeLogNames+="${nextLogName}"
			lstOfHomeLogFiles+="\n${nextLogName}\t[${FIRST_LINE}..${LAST_LINE}] ${timeSpanEpoch} hrs"
			echo -e "InTheRange: ${nextLogName} * ${FIRST_LINE} - ${LAST_LINE}" #Debug/Verbose
		elif [[ ${is_range_found} -eq 1 ]]; then
			echo -e "OutOfRange: ${nextLogName}   ${FIRST_LINE} - ${LAST_LINE}" #Debug/Verbose
			#break
		else
			echo -e "NotInRgYet: ${nextLogName}   ${FIRST_LINE} - ${LAST_LINE}" #Debug/Verbose
		fi
	else
		echo "FileNotFnd: ${nextLogName}" #Debug/Verbose
	fi
done

#echo "~~~Parsing HOME logs..." #Debug/Verbose
if [[ "${#HomeLogNamesArr[@]}" -gt 0 ]]; then
	echo -e "\n~HOME logs in range from: ${RangeHeadDate} ${RangeHeadTime} to: ${RangeTailDate} ${RangeTailTime}:${lstOfHomeLogFiles}" >> ${FileSeismoErrorsDensity}
	echo "~Chart Legend: [(*) Clogging, (.) Other Errors], Filters detailes:" >> ${FileSeismoErrorsDensity}
	echo " * ${FilterHomeBlend}" | sed 's/\[\[:space:\]\]/ /g' >> ${FileSeismoErrorsDensity}
	echo " . ${FilterDistilledForDots}" | sed 's/\[\[:space:\]\]/ /g' >> ${FileSeismoErrorsDensity}
	echo -e "~Errors Density (errors per min):\n" >> ${FileSeismoErrorsDensity}

	CACHE_LogsRecords=$(grep -Eh "${LeadingIsoDateRegex}" ${HomeLogNames} | grep -vE "${FilterLog4jExcludeLevels}" | date_range_full) #Capture the base filtered logs in RAM
	#--Line-by-line horizontal merge using subshell process substitution, #index 0: YYYY-MM-DD_HH:mm (e.g: 2026-05-16_14:06)
	join -a1 -a2 -e "" -o '0,1.2,2.2' \
		<(echo "${CACHE_LogsRecords}" | grep -E "${FilterHomeBlend}" | grep -v "${FilterDistilledForDots}" | cut -c 1-16 | uniq -c | print_seismographFullLine "${compressRate}" "$thresholdHome" "*") \
		<(echo "${CACHE_LogsRecords}" | grep -E "${FilterDistilledForDots}" | cut -c 1-16 | uniq -c | print_seismographFullLine "${compressRate}" "$thresholdHome" ".") |
	sort >> ${FileSeismoErrorsDensity}

	#--Save all error lines
	echo -e "\n~HOME logs ERRORS EXCERPT in range from ${RangeHeadDate} ${RangeHeadTime} to ${RangeTailDate} ${RangeTailTime}:\n${lstOfHomeLogFiles}\n" >> ${SeismoHomeLogsErrorsExcerpt}
	grep -Eh ${LeadingIsoDateRegex} ${HomeLogNames} | date_range_full | grep -vE "${FilterLog4jExcludeLevels}" | grep -E "${FilterDistilledForDots}|${FilterHomeBlend}" | sort >> ${SeismoHomeLogsErrorsExcerpt}
else
	echo "~No access to HOME logs at: ${APP_HOME}, or logs in range not found." >> ${FileSeismoErrorsDensity}
fi

elapsed=$(( ($(date +%s%N) - start_time) / 1000000000 )); min=$(( elapsed / 60 )); sec=$(( elapsed % 60 ))
echo "~4.Elapsed ${min}:${sec}. Compress Original Home logs..."

#--compress/zip original logs
tar -czvf ${SeismoHomeLogsOrig} ${HomeLogNames}

elapsed=$(( ($(date +%s%N) - start_time) / 1000000000 )); min=$(( elapsed / 60 )); sec=$(( elapsed % 60 ))
echo "~5.Elapsed ${min}:${sec}."

}
#EOF
#======

exit 0
#-HOME_LOG_ALL_IN_TIME_RANGE_CLIP
echo "~6.Save HOME_LOGS_ALL_IN_TIME_RANGE_CLIP in the range: ${XcrptHeadDateTime}..${XcrptTailDateTime}" #Debug/Verbose
echo -e "~HOME_LOGS_ALL_IN_TIME_RANGE_CLIP in range from ${XcrptHeadDateTime} to ${XcrptTailDateTime}:\n${XcrptFromTheLog// /\\n}" > ${SeismoHomeLogsAllInTimeRange}
echo "" >> ${SeismoHomeLogsAllInTimeRange}
grep -Eh ${LeadingIsoDateRegex} ${XcrptFromTheLog} | date_range_excerpt >> "${SeismoHomeLogsAllInTimeRange}"
#grep -Eh ${LeadingIsoDateRegex} ${XcrptFromTheLog} | date_range_excerpt | sed 'G' >> "${SeismoHomeLogsAllInTimeRange}" #With Extra \n

#--Script execution time
elapsed=$(( ($(date +%s%N) - start_time) / 1000000000 )); min=$(( elapsed / 60 )); sec=$(( elapsed % 60 ))
echo "~7.Elapsed ${min}:${sec}. Batch execution complete."

#--Zip all files in ./seismolog/
tar -czvf seismolog.zip seismolog/*

