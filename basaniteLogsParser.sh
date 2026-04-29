#!/bin/bash
#--Jira Node Failure Root Cause Analyzer. Scans jira + catalina logs for fatal patterns
#--Basanite by Valeri Tikhonov, TD, April 2026.

#JIRA_LOG=${1:-/home/user/atlassian-jira-home/log/atlassian-jira.log}
#CATALINA_LOG=${2:-/home/user/atlassian-jira-software/logs/catalina.out}
JIRA_LOG=${1:-/media/user/Storage/@jira_logs_copy/logsamples/home_logs/atlassian-jira.log}
CATALINA_LOG=${2:-/media/user/Storage/@jira_logs_copy/jira_sys/logs/catalina.out}

# ./media/user/Storage/lenovo-storage/@Mobile/@Wiki/Projects/@Java/@Jira/temp_collection_of_scripts_to_be_sorted/bash/basaniteLogs.sh #--RUN
TMP=/media/user/Storage/lenovo-storage/@Mobile/@Wiki/Projects/@Java/@Jira/temp_collection_of_scripts_to_be_sorted/bash/tmp/jira_log_analysis_$(date +%Y%m%d-%H%M%S)
mkdir -p $TMP
#sudo su - user
#echo ~~Logs used:
#echo Jira log: $JIRA_LOG
#echo Catalina: $CATALINA_LOGLast 50 ERROR timeline:
#jiraLogName=$(basename "$JIRA_LOG")
#catalinaLogName=$(basename "$CATALINA_LOG")
jiraLogName="${JIRA_LOG##*/}"
catalinaLogName="${CATALINA_LOG##*/}"

#--Use Linear Array example:
#keywordsArr=("word1" "word2")
#keywordsArr+=("word3")
#1. for keyword in ${keywordsArr[@]}
#2. for i in ${!keywordsArr[@]}
#3. length=${#keywordsArr[@]}
#3. for ((i=0; i<length; i++)); do
#	echo -e "\n~~$i. ${keywordsArr[$i]}~~" >> $RCAReportLog #--SubHeader/Filter
#	grep -E ${keywordsArr[$i]} $JIRA_LOG >> $RCAReportLog #--Log extract
#done

#2026-04-23 15:34:53,722-0400
#2026-04-23 15:35:07,600-0400 
DateRange="^2026-04-23[[:space:]]15:3[45]"
DateRange="^2026-04-[0-3]"
RCAReportLog="$TMP/RCAReport.log"
declare -A keywordsMap
keywordsMap=(["Atlassian-errors"]="[[:space:]]+(ERROR|FATAL|SEVERE|CRITICAL)[[:space:]]+" ["Exceptions"]="[A-Za-z0-9\.]+Exception")
keywordsMap["Cluster-health"]="Cluster.*lost|node.*not[[:space:]]responding|heartbeat|split[[:space:]]brain"
keywordsMap["JvmOutOfMemory"]="OutOfMemoryError" #JVM memory failures
keywordsMap["DatabaseFailures"]="connection.*fail|database.*down|PSQLException|SQLTransientConnectionException"
keywordsMap["PluginFailures"]="Plugin.*failed|Unable[[:space:]]to[[:space:]]start[[:space:]]plugin|OSGi|Spring[[:space:]]context[[:space:]]failed"
keywordsMap["ThreadPoolStarvation"]="Thread.*blocked|StuckThread|thread[[:space:]]starvation"
keywordsMap["StuckRequestThreads"]="StuckThread"
keywordsMap["SlowRESTRequests"]="Request.*took|Slow[[:space:]]request" # Detect request timeout / slow endpoints
keywordsMap[""]=""



keywordsMap["NodeShutdownTrigger"]="Shutdown|Stopping[[:space:]]Jira|Jira[[:space:]]is[[:space:]]shutting[[:space:]]down"



for keyword in "${!keywordsMap[@]}"; do
	echo -e "\n~~cat: $jiraLogName, $keyword: '${keywordsMap[$keyword]}'" >> $RCAReportLog #--SubHeader/Filter
	grep -E $DateRange $JIRA_LOG | grep -hE ${keywordsMap[$keyword]} >> $RCAReportLog
	echo -e "\n~~cat: $catalinaLogName, $keyword: '${keywordsMap[$keyword]}'" >> $RCAReportLog #--SubHeader/Filter
	grep -E $DateRange $CATALINA_LOG | grep -hE ${keywordsMap[$keyword]} >> $RCAReportLog
done

##--Detect thread explosion, thread growth
echo -e "\n~~cat: ThreadExplosion" >> $RCAReportLog
grep -E $DateRange $CATALINA_LOG | grep -E "http-nio|http-bio|ThreadPoolExecutor" | grep -E "max[[:space:]]threads|busy[[:space:]]threads|stuck[[:space:]]thread" >> $RCAReportLog


echo -e "\n~~cat: LoadBalancerHealthCheck" >> $RCAReportLog
grep -E "healthcheck|status|heartbeat" $JIRA_LOG | grep -E "fail|timeout|unreachable" >> $RCAReportLog


##--Top exceptions summary
grep -E $DateRange $JIRA_LOG | grep -oE "[A-Za-z0-9\.]+Exception" | sort | uniq -c | sort -nr | head -10 >> $TMP/RCAtopExceptions.log


#--The "Quick Peak"
#--1. extracts the date and time (down to the minute), 
#--2. counts errors per minute, and sorts them so the highest density appears at the top:
#--cut -c 1-16: Clips the first 16 characters of the line (2026-04-29 21:51), this captures the Year-Month-Day Hour:Minute.
#--uniq -c: Groups identical minutes together and counts how many times they appear. Only works if your log file is already in chronological order.
#--sort -n: Sorts the results numerically by the count. The "sharpest" density increase will be at the very bottom of the list.
#grep -E $DateRange $JIRA_LOG | grep -E "[[:space:]]ERROR[[:space:]]" | cut -c 1-16 | uniq -c | sort -nr >> $TMP/RCAMostErrorsPerMinute.log
#--If you want to see the timeline in order but highlight where the jumps happen:
grep -E $DateRange $JIRA_LOG | grep -E "[[:space:]]ERROR[[:space:]]|Exception" | cut -c 1-16 | uniq -c >> $TMP/RCASpikesList.log
#--Visualizing with a "Text Bar Chart"
grep -E $DateRange $JIRA_LOG | grep -E "[[:space:]]ERROR[[:space:]]|Exception" | cut -d' ' -f2 | cut -d':' -f1,2 | sort | uniq -c | awk '{printf "%s %s ", $2, $1; for(i=0; i<$1/10; i++) printf "#"; print ""}' >> $TMP/RCASpikesChart.log



##--echo "Last 50 ERROR timeline:"
tail -50 $JIRA_LOG > $TMP/RCAJiraLogTail.txt
echo "Failure Root Cause Analysys completed. Reports saved to: $TMP"
