#!/usr/bin/env bash

## 全面备份环境

bin=`which $0`
bin=`dirname ${bin}`
bin=`cd "$bin"; pwd`

function print_usage(){
  echo "Usage: trace.sh <id_str> [dir]"
  echo "  id_str           id string of the process to trace"
  echo "                   such as: \$pid, \"datanode\", \"regionserver\", job_attempt_id, container_id"
  echo "                   please use container_id for hadoop-build job or pipes/streaming job"
  echo "  dir              root dir to save dump info. default: current dir"
}

if [ $# = 0 ]; then
  print_usage
  exit
fi

cmd=$(ps axjf | grep $1 | grep -v grep | grep -v "$0" | tail -n 1)
pid=$(echo $cmd | awk '{print $2}')
if [ x"$pid" == x"" ]; then
  echo "can not ps the process:["$1"]"
  exit 1
fi

export JAVA_HOME=/home/hadoop/hadoop_hbase/jdk-current
export HADOOP_HOME=/home/hadoop/hadoop_hbase/hadoop-current



logs=trace-$pid-$(date +%Y%m%d%H%M%S)
if [ $# -gt 1 ]; then
  logs=$2/$logs
fi
mkdir $logs
if [ $? != 0 ]; then
  echo "can not mkdir:["$logs"]"
  exit 1
fi
echo "save file to "$logs

echo "process cmd info"
echo $cmd > $logs/cmd.$pid.log 2>&1

echo "dump env"
cat /proc/$pid/environ > $logs/env.$pid.log 2>&1
if [ $? != 0 ]; then
  echo "no such process pid:["$pid"] or you have not privilege, plz change current user to process's user"
  exit 1
fi

echo "dump jinfo"
$JAVA_HOME/bin/jinfo $pid > $logs/jinfo.$pid.log 2>&1

echo "dump jstack"
$JAVA_HOME/bin/jstack $pid > $logs/jstack.$pid.log 2>&1

echo "dump jmap -heap"
$JAVA_HOME/bin/jmap -heap $pid > $logs/jmap.$pid.log 2>&1

echo "dump pstack"
pstack $pid > $logs/pstack.$pid.log 2>&1

echo "lsof"
lsof -p $pid > $logs/lsof.$pid.log 2>&1 &

echo "top -H -p "
top -b -n 10 -p $pid -H > $logs/top.$pid.log 2>&1 &

echo "netstat"
netstat -apn | grep $pid > $logs/netstat.$pid.log 2>&1 &

echo "ss"
ss -a -o -p -i -n > $logs/ss.$pid.log 2>&1 &

echo "strace -- please wait more than 30s"
echo "Ctl+c to kill strace ......"
strace -f -T -tt -p $pid -e trace=all -o $logs/strace.$pid.log 2>$logs/strace.$pid.out