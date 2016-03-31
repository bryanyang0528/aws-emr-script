#!/bin/bash

set -e
username=$1
WORKDIR=/home/hadoop

aws s3 sync s3://yourPath/aws/bootstrap/ ${WORKDIR}

# Script to add a user to Linux system
sudo useradd $username
sudo cp -R /home/hadoop/.ssh /home/${username}/
sudo chown -R $username:$username /home/${username}/.ssh


# Add Master IP to /etc/hosts
MASTERID=`cat /mnt/var/lib/info/job-flow.json | grep masterInstanceId | awk -F'"' '{print $4}'`
MASTERIP=`aws ec2 describe-instances --instance-ids "${MASTERID}" |grep PrivateIpAddress | head -n 1 | awk -F'"' '{print $4}'`
echo ${MASTERIP}

sudo sh -c  "echo '${MASTERIP} master' >> /etc/hosts"

for filename in ${WORKDIR}/script/*.sh; do
    /bin/bash "$filename" 
done
