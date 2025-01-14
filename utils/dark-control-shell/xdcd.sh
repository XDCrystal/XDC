#!/bin/sh

# Copyright (c) 2016-2018, DCRS developers
# English correction by Grabbers
#
# All rights reserved
#
# Redistribution and use in source and binary forms, with or without modification, are
# permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice, this list of
#    conditions and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above copyright notice, this list
#    of conditions and the following disclaimer in the documentation and/or other
#    materials provided with the distribution.
#
# 3. Neither the name of the copyright holder nor the names of its contributors may be
#    used to endorse or promote products derived from this software without specific
#    prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY
# EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL
# THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
# PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
# STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF
# THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


DATA_DIR="/var/dcrs"
LOG_DIR="/var/log/dcrs"
RUN_DIR="/var/run/dcrs"
TMP_DIR="/tmp"
HTDOCS_DIR="/tmp"

XDCD="/usr/sbin/darkcrystald"

XDCD_P2P_IP="0.0.0.0"
XDCD_P2P_PORT="15260"
XDCD_RPC_IP="127.0.0.1"
XDCD_RPC_PORT="15261"
XDCD_LOG_LEVEL="2"
XDCD_FEE_ADDRESS="XDC1Mm9jmBwGuYnYZhQicQb9SESKB76eQDtQ2u7cBeSjNQhpPytJ6rkHhVGYQww6PB4Fe7CKeJsmj5AxxihTSfim1JiFMW8SKM"
XDCD_VIEW_KEY=""

XDCS_CONTROL="/usr/lib/dcrs/xdcs.sh"

SIGTERM_TIMEOUT=240
SIGKILL_TIMEOUT=120

ZIP="/usr/bin/zip"


## Base check

# Check all work directories
if [ -d $DATA_DIR ]; then
  if [ ! -w $DATA_DIR ]; then
    echo "Error: DATA dir not writable!"
    exit 1
  fi
else
  echo "Error: DATA dir not found!"
  exit 1
fi

if [ -d $LOG_DIR ]; then
  if [ ! -w $LOG_DIR ]; then
    echo "Error: LOG dir not writable!"
    exit 1
  fi
else
  echo "Error: LOG dir not found!"
  exit 1
fi

if [ -d $RUN_DIR ]; then
  if [ ! -w $RUN_DIR ]; then
    echo "Error: RUN dir not writable!"
    exit 1
  fi
else
  echo "Error: RUN dir not found!"
  exit 1
fi

if [ -d $TMP_DIR ]; then
  if [ ! -w $TMP_DIR ]; then
    echo "Error: TMP dir not writable!"
    exit 1
  fi
else
  echo "Error: TMP dir not found!"
  exit 1
fi

if [ -d $HTDOCS_DIR ]; then
  if [ ! -w $HTDOCS_DIR ]; then
    echo "Error: HTDOCS dir not writable!"
    exit 1
  fi
else
  echo "Error: HTDOCS dir not found!"
  exit 1
fi

# Check all files
if [ ! -f $XDCD ]; then
  echo "Error: DEAMON bin file not found!"
  exit 1
fi

if [ ! -f $ZIP ]; then
  echo "Error: ZIP archiver bin file not found!"
  exit 1
fi

if [ ! -f $XDCS_CONTROL ]; then
  echo "Error: XDCS start script file not found!"
  exit 1
fi



# Function logger
logger(){
  if [ ! -f $LOG_DIR/xdcd_control.log ]; then
    touch $LOG_DIR/xdcd_control.log
  fi
  mess=[$(date '+%Y-%m-%d %H:%M:%S')]" "$1
  echo $mess >> $LOG_DIR/xdcd_control.log
  echo $mess
}

# Funstion locker
locker(){
  if [ "$1" = "check" ]; then
    if [ -f $RUN_DIR/xdcd_control.lock ]; then
      logger "LOCKER: previous task is not completed; exiting..."
      exit 0
    fi
  fi
  if [ "$1" = "init" ]; then
    touch $RUN_DIR/xdcd_control.lock
  fi
    if [ "$1" = "end" ]; then
    rm -f $RUN_DIR/xdcd_control.lock
  fi
}

# Function init service
service_init(){
  $XDCD --data-dir $DATA_DIR \
        --log-file $LOG_DIR/xdcd.log \
        --log-level $XDCD_LOG_LEVEL \
        --restricted-rpc \
        --no-console \
        --enable-cors "*" \
        --p2p-bind-ip $XDCD_P2P_IP \
        --p2p-bind-port $XDCD_P2P_PORT \
        --rpc-bind-ip $XDCD_RPC_IP \
        --rpc-bind-port $XDCD_RPC_PORT \
        --fee-address $XDCD_FEE_ADDRESS \
        --view-key $XDCD_VIEW_KEY > /dev/null & echo $! > $RUN_DIR/XDCD.pid
}

# Function start service
service_start(){
  if [ ! -f $RUN_DIR/XDCD.pid ]; then
    logger "START: trying to start service..."
    service_init
    sleep 5
    if [ -f $RUN_DIR/XDCD.pid ]; then
      pid=$(sed 's/[^0-9]*//g' $RUN_DIR/XDCD.pid)
      if [ -f /proc/$pid/stat ]; then
        logger "START: success!"
      fi
    fi
  else
    pid=$(sed 's/[^0-9]*//g' $RUN_DIR/XDCD.pid)
    if [ -f /proc/$pid/stat ]; then
      logger "START: process is already running"
    else
      logger "START: abnormal termination detected; starting..."
      rm -f $RUN_DIR/XDCD.pid
      service_init
      sleep 5
      if [ -f $RUN_DIR/XDCD.pid ]; then
        pid=$(sed 's/[^0-9]*//g' $RUN_DIR/XDCD.pid)
        if [ -f /proc/$pid/stat ]; then
          logger "START: success!"
        fi
      fi
    fi
  fi
}

# Function stop service
service_stop(){
  if [ -f $RUN_DIR/XDCD.pid ]; then
    logger "STOP: attempting to stop the service..."
    pid=$(sed 's/[^0-9]*//g' $RUN_DIR/XDCD.pid)
    if [ -f /proc/$pid/stat ]; then
      kill $pid
      sleep 5
      for i in $(seq 1 $SIGTERM_TIMEOUT); do
        if [ ! -f /proc/$pid/stat ]; then
          rm -f $RUN_DIR/XDCD.pid
          logger "STOP: success!"
          break
        fi
        sleep 1
      done
      if [ -f $RUN_DIR/XDCD.pid ]; then
        logger "STOP: attempt failed, trying again..."
        kill -9 $pid
        sleep 5
        for i in $(seq 1 $SIGKILL_TIMEOUT); do
          if [ ! -f /proc/$pid/stat ]; then
            rm -f $RUN_DIR/XDCD.pid
            logger "STOP: service has been killed (SIGKILL) due to ERROR!"
            break
          fi
          sleep 1
        done
      fi
    else
      logger "STOP: PID file found, but service not detected; possible error..."
      rm -f $RUN_DIR/XDCD.pid
    fi
  else
    logger "STOP: no service found!"
  fi
}

# Function archiver blockchain
archiver(){
  logger "ARCHIVER: began"
  if [ -f $DATA_DIR/blocks.dat ] && [ -f $DATA_DIR/blockindexes.dat ]; then
    cd $TMP_DIR
    if [ -d blockchain ]; then
      rm -rf -f blockchain
    fi
    mkdir blockchain
    logger "ARCHIVER: copying target files..."
    cp $DATA_DIR/blocks.dat blockchain/blocks.dat
    cp $DATA_DIR/blockindexes.dat blockchain/blockindexes.dat
    logger "ARCHIVER: packing target files..."
    $ZIP -r blockchain.zip blockchain
    logger "ARCHIVER: calculating md5sum..."
    md5sum blockchain.zip >> blockchain.txt
    rm -rf -f blockchain
    if [ -f $HTDOCS_DIR/blockchain.zip ]; then
      rm -f $HTDOCS_DIR/blockchain.zip
    fi
    if [ -f $HTDOCS_DIR/blockchain.txt ]; then
      rm -f $HTDOCS_DIR/blockchain.txt
    fi
    mv blockchain.zip $HTDOCS_DIR/blockchain.zip
    mv blockchain.txt $HTDOCS_DIR/blockchain.txt
    logger "ARCHIVER: finished!"
  else
    logger "ARCHIVER: error, target files not found!"
  fi
}

# Function checker
checker(){
  logger "CHECKER: began"
  if [ -f $RUN_DIR/XDCD.pid ]; then
    pid=$(sed 's/[^0-9]*//g' $RUN_DIR/XDCD.pid)
    if [ -f /proc/$pid/stat ]; then
      logger "CHECKER: all fine!"
    else
      logger "CHECKER: abnormal termination detected; restarting..."
      do_restart
    fi
    logger "CHECKER: finished!"
  else
    logger "CHECKER: target service not found"
  fi
}

# Fucntion check simplewallet is was started
IS_XDCS="stop"
is_run_simplewallet(){
  if [ -f $RUN_DIR/XDCS.pid ]; then
    IS_XDCS="run"
  fi
}


do_start(){
  logger "DO START: procedure initializing..."
  service_start
  logger "DO START: ok"
}

do_stop(){
  is_run_simplewallet
  logger "DO STOP: procedure initializing..."
  if [ "$IS_XDCS" = "run" ]; then
    logger "DO STOP: stopping dependant service..."
    $XDCS_CONTROL --stop > /dev/null
  fi
  service_stop
  logger "DO STOP: ok"
}

do_restart(){
  is_run_simplewallet
  logger "DO RESTART: procedure initializing..."
  if [ "$IS_XDCS" = "run" ]; then
    logger "DO RESTART: Simplewallet was started and will be stopped. Stopping Simplewallet service..."
    $XDCS_CONTROL --stop > /dev/null
  fi
  service_stop
  service_start
  if [ "$IS_XDCS" = "run" ]; then
    logger "DO RESTART: Simplewallet will be started again. Waiting for the node to be ready..."
    sleep 15
    logger "DO RESTART: starting Simplewallet service..."
    $XDCS_CONTROL --start > /dev/null
  fi
  logger "DO RESTART: ok"
}

do_check(){
  logger "DO CHECK: procedure initializing..."
  checker
  logger "DO CHECK: ok"
}

do_archiver(){
  logger "DO ARCHIVER: procedure initializing..."
  service_stop
  archiver
  service_start
  logger "DO ARCHIVER: ok"
}


# Command selector
locker "check"
locker "init"

case "$1" in
  "--start")
  do_start
  ;;
  "--stop")
  do_stop
  ;;
  "--restart")
  do_restart
  ;;
  "--check")
  do_check
  ;;
  "--archive")
  do_archiver
  ;;
  *)
  logger "SELECTOR: unknown command"
  ;;
esac

locker "end"
