#!bin/bash

set -e

WORKDIR=`pwd`
HOMEDIR="/home/hadoop"

sudo yum install -y mlocate git
sudo updatedb

# install anaconda
mkdir temp && cd temp
wget https://3230d63b5fc54e62148e-c95ac804525aac4b6dba79b00b39d1d3.ssl.cf1.rackcdn.com/Anaconda2-2.4.1-Linux-x86_64.sh
bash Anaconda2-2.4.1-Linux-x86_64.sh -b
sudo sh -c "echo 'export PATH=\"/home/hadoop/anaconda2/bin:$PATH\"' >> /etc/bashrc"

# set ipython notebook for spark
sudo sh -c "echo 'export IPYTHON=1' >> /etc/bashrc"
sudo sh -c "echo 'export PYSPARK_PYTHON=\"/home/hadoop/anaconda2/bin/python\"' >> /etc/bashrc"
sudo sh -c "echo 'export PYSPARK_DRIVER_PYTHON=\"/home/hadoop/anaconda2/bin/python\"' >> /etc/bashrc"

# install other packages
#conda install -y seaborn

# clear temp
sudo rm -rf ${WORKDIR}/temp
