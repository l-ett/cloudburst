#!/bin/bash

#  Copyright 2019 U.C. Berkeley RISE Lab
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.

IP=`ifconfig eth0 | grep 'inet' | grep -v inet6 | sed -e 's/^[ \t]*//' | cut -d' ' -f2`

# A helper function that takes a space separated list and generates a string
# that parses as a YAML list.
gen_yml_list() {
  IFS=' ' read -r -a ARR <<< $1
  RESULT=""

  for IP in "${ARR[@]}"; do
    RESULT=$"$RESULT        - $IP\n"
  done

  echo -e "$RESULT"
}


# Download latest version of the code from relevant repository & branch -- if
# none are specified, we use hydro-project/cloudburst by default. Install the KVS
# client from the Anna project.
cd $HYDRO_HOME/anna
git remote remove origin
git remote add origin https://github.com/hydro-project/anna
while !(git fetch -p origin); do
   echo "git fetch failed, retrying..."
done

git checkout -b brnch origin/master
git submodule sync
git submodule update

cd client/python
python3.6 setup.py install

cd $HYDRO_HOME/cloudburst

git remote remove origin
git remote add origin https://github.com/hydro-project/cloudburst
while !(git fetch -p origin); do
   echo "git fetch failed, retrying..."
done

git checkout -b brnch origin/master
git submodule sync
git submodule update

# Compile protobufs and run other installation procedures before starting.
./scripts/build.sh

touch conf/cloudburst-config.yml
echo "ip: $IP" >> conf/cloudburst-config.yml
echo "mgmt_ip: $MGMT_IP" >> conf/cloudburst-config.yml

# Add the current directory to the PYTHONPATH in order to resolve imports
# correctly.
export PYTHONPATH=$PYTHONPATH:$(pwd)
  cp  $HYDRO_HOME/anna/conf/anna-local.yml  ./conf/anna-config.yml

  $HYDRO_HOME/anna/build/target/kvs/anna-monitor &
  MPID=$!
  $HYDRO_HOME/anna/build/target/kvs/anna-route &
  RPID=$!
  export SERVER_TYPE="memory"
  $HYDRO_HOME/anna/build/target/kvs/anna-kvs &
  SPID=$!

  echo $MPID > pids
  echo $RPID >> pids
  echo $SPID >> pids
  python3.6 cloudburst/server/scheduler/server.py conf/cloudburst-local.yml &
  SPID=$!
  python3.6 cloudburst/server/executor/server.py conf/cloudburst-local.yml &
  EPID=$!

  echo $SPID > pids
  echo $EPID >> pids
  
  while :
  do
    echo Keep running
    echo "Press CTRL+C to exit"
    sleep 10
  done
fi

