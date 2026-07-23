#!/bin/bash
# Confluence Thread + CPU Dump Collector
# Creates:
# 1. Timestamped zip with node name
# 2. Easy latest zip for SFTP download
DUMP_BASE="/opt/atlassian/confluence/home/logs/thread-dumps"
NODE=$(hostname -s)
HOST=$(hostname -f)
TS=$(date +%Y%m%d_%H%M%S)
PID=$(ps -ef  | awk '/java/ && /confluence/ && !/awk/ {print $2; exit}')
if [ -z "$PID" ]; then
	echo "ERROR: Could not find Confluence Java PID"
	exit 1
fi
OUT_DIR="${DUMP_BASE}/confluence_dump_${NODE}_${TS}"
mkdir -p "$OUT_DIR"
echo "Confluence Thread + CPU Dump Capture"
echo "Host: $HOST"
echo "Node: $NODE"
echo "PID: $PID"
echo "Output dir: $OUT_DIR"
echo "Started: $(date)"
for i in 1 2 3; do
	NOW=$ (date +%Y%m%d_%H%M%S)
	echo "Capture $i at $(date)" | tee "$OUT_DIR/capture_${i}_time.txt"
	top -H -b -n 1 -p "$PID" > "$OUT_DIR/cpu_threads_top_${i}_${NOW}.txt"
	jstack -l "$PID" > "$OUT_DIR/thread_dump_${i}_${NOW}.txt"
	sleep 10
done
cd "$DUMP_BASE" || exit 1
FOLDER_NAME=$(basename "$OUT_DIR")
LOCAL_ZIP="${DUMP_BASE}/${FOLDER_NAME}.zip"
TIMESTAMPED_ZIP="/tmp/${FOLDER_NAME}.zip"
LATEST_ZIP="/tmp/confluence_dump_latest_${NODE}.zip"
zip -qr "$LOCAL_ZIP" "$FOLDER_NAME"
cp "$LOCAL_ZIP" "$TIMESTAMPED_ZIP"
chmod 644 "$TIMESTAMPED_ZIP"
cp "$TIMESTAMPED_ZIP" "$LATEST_ZIP"
chmod 644 "$LATEST_ZIP"
echo "DONE"
echo "Completed: $(date)"
echo "TIMESTAMPED_ZIP: $TIMESTAMPED_ZIP"
echo "EASY_DOWNLOAD: $LATEST_ZIP"
ls -lh "$TIMESTAMPED_ZIP" "$LATEST_ZIP"
