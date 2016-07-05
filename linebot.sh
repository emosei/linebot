#!/bin/sh

NAME="[ LineBot DAEMON ]"
PID="./linebot.pid"
CMD="ruby linebot.rb"

#test

start()
{
  if [ -e $PID ]; then
    echo "$NAME already started"
    exit 1
  fi
  echo "$NAME START!"
  $CMD
}

stop()
{
  if [ ! -e $PID ]; then
    echo "$NAME not started"
    exit 1
  fi
  echo "$NAME STOP!"
  kill -9 `cat ${PID}`
  rm $PID
}

restart()
{
  stop
  sleep 2
  start
}

case "$1" in
  start)
    start
    ;;
  stop)
    stop
    ;;
  restart)
    restart
    ;;
  *)
    echo "Syntax Error: release [start|stop|restart]"
    ;;
esac
