#!/bin/bash
#Auhor: Bryan Yang
#Date: 2016/01/20
#Latest Update: 2016/02/23
#Description: Control EMR Cluster
#  Functions:
#    create:  create [USER NAME] [INSTANCE TYPE|m3.xlarge] [CORE NODE]
#    login: login [CLUSTER ID] [PATH OF KEY]
#    status: status [CLUSTER ID]
#    terminate: terminate [CLUSTER ID]
#  Update Information:
#    160325 fixed empty culusterid.tmp bug, add conf file for user name, key name, and instatnce type.
#    160324 fix return code, save cluster id automatacally
#    160223 bug fixed
#    160222 Add Hive Authorization, add remote hue database
#    160218 Add exe remote EMR command, add user login
#    160214 Create EMR use customized Key-Pair
#    160201 Add tag
#    160130 Add Bootstrap:
#             copy Bootstrap folder to /home/hadoop/
#             copy user folder to /home/hadoop/
#             install locate, anaconda, set ipython for pyspark

ACTION=$1

create () {

  
    [[ -s /tmp/clusterid.tmp ]] && echo "There is a runing EMR, please terminate it first." && exit 9
        
    if [[ $# -eq 2 ]] ; then

	    getConf
	    rm -f /tmp/clusterid.tmp
	    INSTANCE=$1
	    CORECOUNT=$2
	    BP=`cat emr_env.conf | grep $INSTANCE | awk '{print $2}'`

	    echo "USER = ${USER}, KEY= ${KEY}, INSTANCE TYPE = ${INSTANCE}, BidPrice = ${BP}, Slave = ${CORECOUNT}"
	    echo 'CREATING EMR CLUSTERS...'
	    aws emr create-cluster \
		    --applications Name=Hadoop Name=Hive Name=Spark Name=Hue \
		    --ec2-attributes KeyName="${KEY}",InstanceProfile="EMR_EC2_Data",SubnetId="subnet",EmrManagedSlaveSecurityGroup="slaveSecurityGroup",EmrManagedMasterSecurityGroup="masterSecurityGroup" \
		    --service-role EMR_Data \
		    --enable-debugging \
		    --release-label emr-4.2.0 \
		    --log-uri "s3n://yourPath/log/${USER}aws-logs-emr/elasticmapreduce/" \
		    --name "Data-BI-${USER}" \
		    --tags user=${USER} \
		    --instance-groups InstanceCount=1,InstanceGroupType=MASTER,InstanceType=${INSTANCE},Name="Master instance group - 1",BidPrice=${BP} InstanceCount=${CORECOUNT},InstanceGroupType=CORE,InstanceType=${INSTANCE},Name="Core instance group",BidPrice=${BP} \
		    --configurations file://dataConfig.json \
		    --region ap-northeast-1 \
		    --bootstrap-action Path="file:///usr/bin/aws",Name="copyToAll",Args="s3","sync","s3://path","/home/hadoop/"   Path="file:///bin/bash",Args="/home/hadoop/bootstrap.sh","${USER}" \
	            --steps Type=CUSTOM_JAR,Name=CustomJAR,ActionOnFailure=CONTINUE,Jar=s3://elasticmapreduce/libs/script-runner/script-runner.jar,Args=[s3://yourPath/aws/bootstrap/script/system.beta,${USER}] | grep ClusterId | awk -F'"' '{print $4}' > /tmp/clusterid.tmp

	    echo `cat /tmp/clusterid.tmp` 
	    exit 0


    else
	    echo "create [m1.medium|m3.xlarge] [CORE NODE]"
	    exit 9
    fi
}


login () {

	getId
        getConf
	STATE=`status | awk '{print $3}'`

        if [[ ${STATE} = "WAITING" ]]; then
            
            HOSTNAME=`aws emr describe-cluster --cluster-id ${ID} | grep MasterPublicDnsName | awk -F':' '{print $2}' | awk -F'"' '{print $2}'`
	    echo "LOGIN ${ID} ..."
	    ssh -i ${KEYDIR} ${USER}@${HOSTNAME}
	else 
            echo "${ID} is ${STATE}"
	    exit 0
        fi

}

exe () {

      if [[ $# -eq 1 ]]; then

        getId
        getConf
        SCRIPT=$1

        STATE=`status ${ID}|awk '{print $3}'`

        if [[ ${STATE} = "WAITING" ]]; then

            HOSTNAME=`aws emr describe-cluster --cluster-id ${ID} | grep MasterPublicDnsName | awk -F':' '{print $2}' | awk -F'"' '{print $2}'`
            echo "LOGIN ${ID} ..." 1>&2
            ssh -i ${KEYDIR} ${USER}@${HOSTNAME} "${SCRIPT}"
        else
            echo "${ID} is ${STATE}"
            exit 9
        fi

    else
        echo "exec [SCRIPT]"
        exit 9
    fi
  

}

terminate () {

    getId
    echo "START TO TERMINATE ${ID} ..."
    aws emr terminate-clusters --cluster-ids ${ID}
    rm -f /tmp/clusterid.tmp

} 

status () {

    getId
    STATE=`aws emr describe-cluster --cluster-id ${ID} | grep State | head -n 1 | awk -F':' '{print $2}' | awk -F'"' '{print $2}'`
    echo "${ID} is ${STATE}"
    	
}

getId () {
    
	if [[ -e /tmp/clusterid.tmp  ]] ; then
	
		ID=`cat /tmp/clusterid.tmp` 
	
            if  [[ -z "${ID}" ]]; then
                
		rm -f /tmp/clusterid.tmp
		echo "Cluster id is not exist"
		exit 9

	    fi

	else
		echo "Cluster id is not exist" 
		exit 9  
	fi

}

getConf() {

	KEY=`cat emr_env.conf | grep key_name | awk '{print $2}'`
	KEYDIR=`cat emr_env.conf | grep key_dir | awk '{print $2}'`
	USER=`cat emr_env.conf | grep user | head -n 1 | awk '{print $2}'`

}



if [[ $# -eq 0 ]];
then
	echo "| create | login | status | terminate | exec |"
	exit 9

elif [[ ${ACTION} = "create" ]]; 
then
	if [[ $# -eq 3  ]] ; then
	    create $2 $3
	else
	    echo "create [m1.medium|m3.xlarge] [CORE NODE]"
	    exit 9
	fi

elif [[ ${ACTION} = "login" ]];
then
	if [[ $# -eq 1   ]] ; then
	    login
	else
            echo "login"
	    exit 9
	fi

elif [[ ${ACTION} = "exec" ]];
then
        exe "$2"

elif [[ ${ACTION} = "terminate" ]];
then
	terminate

elif [[ ${ACTION} = "status" ]];
then
	status
else
        echo "No supported function are passed to shell script"
	exit 9
fi

