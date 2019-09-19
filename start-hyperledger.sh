#!/bin/bash

NAMESPACE=""

################ KAFKA AND ZOOKEEPER DEPLOYMENT ################

if [ -d "${PWD}/configFiles" ]; then
    KUBECONFIG_FOLDER=${PWD}/configFiles
else
    echo "Configuration files are not found."
    exit
fi

if [ ! -z $1 ]; then
    NAMESPACES=`kubectl get namespaces | awk 'NR>1 {print $1}'`

    for ns in ${NAMESPACES[@]}; do
        if [ $1 = $ns ]; then
	    echo "Namespace \"$ns\" exists. Deployment set there." 
            NAMESPACE=$ns
	fi
    done
	
    if [ -z $NAMESPACE ]; then
        echo "Namespace \"$1\" does not exist. Create it manually first."
        exit
    fi
else
    echo "You must specify a namespace as an argument."
    exit
fi

# Create Zookeeper deployment
kubectl create -n $NAMESPACE -f ${KUBECONFIG_FOLDER}/zookeeper.yaml

ZK_STATUS=$(kubectl get pods -n $NAMESPACE | grep zk | awk '{print $3}')
ZK_CREATING="true"

while [ "${ZK_CREATING}" = "true" ]; do
    echo "Creating Zookeeper instances"
    for zk in ${ZK_STATUS}; do
        if [ ! "${zk}" = "Running" ]; then
            sleep 5
            ZK_STATUS=$(kubectl get pods -n $NAMESPACE | grep zk | awk '{print $3}')
        else
            echo "Zookeeper instances created"
            ZK_CREATING="false"
        fi
    done
done

sleep 30

# Create Kafka deployment
cat $KUBECONFIG_FOLDER/kafka.yaml | sed "s/{{NAMESPACE}}/$NAMESPACE/g" | kubectl apply -n $NAMESPACE -f -
#kubectl create -f ${KUBECONFIG_FOLDER}/kafka.yaml

KAFKA_STATUS=$(kubectl get pods -n $NAMESPACE | grep kafka | awk '{print $3}')
KAFKA_CREATING="true"

while [ "${KAFKA_CREATING}" = "true" ]; do
    echo "Creating Kafka instances"
    for kafka in ${KAFKA_STATUS}; do
        if [ ! "${kafka}" = "Running" ]; then
            sleep 5
            KAFKA_STATUS=$(kubectl get pods -n $NAMESPACE | grep kafka | awk '{print $3}')
        else
            echo "Kafka instances created"
            KAFKA_CREATING="false"
        fi
    done
done

echo "Network deployment begins in 10 seconds."
sleep 10

################ NETWORK DEPLOYMENT #################

# Create Docker deployment
if [ "$(cat ${KUBECONFIG_FOLDER}/peersDeployment.yaml | grep -c tcp://docker:2375)" != "0" ]; then
    echo "peersDeployment.yaml file was configured to use Docker in a container."
    echo "Creating Docker deployment"

    kubectl create -n $NAMESPACE -f ${KUBECONFIG_FOLDER}/docker-volume.yaml
    kubectl create -n $NAMESPACE -f ${KUBECONFIG_FOLDER}/docker.yaml
    sleep 5

    dockerPodStatus=$(kubectl get pods -n $NAMESPACE --selector=name=docker --output=jsonpath={.items..phase})

    while [ "${dockerPodStatus}" != "Running" ]; do
        echo "Wating for Docker container to run. Current status of Docker is ${dockerPodStatus}"
        sleep 5;
        if [ "${dockerPodStatus}" == "Error" ]; then
            echo "There is an error in the Docker pod. Please check logs."
            exit 1
        fi
        dockerPodStatus=$(kubectl get pods -n $NAMESPACE --selector=name=docker --output=jsonpath={.items..phase})
    done
fi

# Creating Persistant Volume
echo -e "\nCreating volume"
if [ "$(kubectl get pvc -n $NAMESPACE | grep shared-pvc | awk '{print $2}')" != "Bound" ]; then
    echo "The Persistant Volume does not seem to exist or is not bound"
    echo "Creating Persistant Volume"

    if [ "$1" == "--paid" ]; then
        echo "You passed argument --paid. Make sure you have an IBM Cloud Kubernetes - Standard tier. Else, remove --paid option"
        echo "Running: kubectl create -n $NAMESPACE -f ${KUBECONFIG_FOLDER}/createVolume-paid.yaml"
        kubectl create -n $NAMESPACE -f ${KUBECONFIG_FOLDER}/createVolume-paid.yaml
        sleep 5
    else
        echo "Running: kubectl create -f ${KUBECONFIG_FOLDER}/createVolume.yaml"
        kubectl create -n $NAMESPACE -f ${KUBECONFIG_FOLDER}/createVolume.yaml
        sleep 5
    fi

    if [ "kubectl get pvc -n $NAMESPACE | grep shared-pvc | awk '{print $3}'" != "shared-pv" ]; then
        echo "Success creating Persistant Volume"
    else
        echo "Failed to create Persistant Volume"
    fi
else
    echo "The Persistant Volume exists, not creating again"
fi


# Copy the required files(configtx.yaml, cruypto-config.yaml, sample chaincode etc.) into volume
echo -e "\nCreating Copy artifacts job."
echo "Running: kubectl create -n $NAMESPACE -f ${KUBECONFIG_FOLDER}/copy-artifacts-job.yaml"
kubectl create -n $NAMESPACE -f ${KUBECONFIG_FOLDER}/copy-artifacts-job.yaml

pod=$(kubectl get pods -n $NAMESPACE --selector=job-name=copyartifacts --output=jsonpath={.items..metadata.name})

podSTATUS=$(kubectl get pods -n $NAMESPACE --selector=job-name=copyartifacts --output=jsonpath={.items..phase})

while [ "${podSTATUS}" != "Running" ]; do
    echo "Wating for container of copy artifact pod to run. Current status of ${pod} is ${podSTATUS}"
    sleep 5;
    if [ "${podSTATUS}" == "Error" ]; then
        echo "There is an error in copyartifacts job. Please check logs."
        exit 1
    fi
    podSTATUS=$(kubectl get pods -n $NAMESPACE --selector=job-name=copyartifacts --output=jsonpath={.items..phase})
done

echo -e "${pod} is now ${podSTATUS}"
echo -e "\nStarting to copy artifacts in persistent volume."

#fix for this script to work on icp and ICS
kubectl cp -n $NAMESPACE ./artifacts $pod:/shared/
echo "Waiting for 10 more seconds for copying artifacts to avoid any network delay"
sleep 10

# Create CA deployment
kubectl apply -n $NAMESPACE -f ${KUBECONFIG_FOLDER}/ca-deployment.yaml
ROOT_CA_STATUS=$(kubectl get pods -n $NAMESPACE | grep root-ca | awk '{print $3}')
ROOT_CA_CREATING="true"

INTERMEDIATE_CA_STATUS=$(kubectl get pods -n $NAMESPACE | grep intermediate-ca | awk '{print $3}')
INTERMEDIATE_CA_CREATING="true"

while [ "${ROOT_CA_CREATING}" = "true" ]; do
    echo "Creating root CA instance"
        if [ ! "${ROOT_CA_STATUS}" = "Running" ]; then
            sleep 5
            ROOT_CA_STATUS=$(kubectl get pods -n $NAMESPACE | grep root-ca | awk '{print $3}')
        else
            echo "Root CA instance created"
            sleep 20
            ROOT_CA_CREATING="false"
        fi
done

while [ "${INTERMEDIATE_CA_CREATING}" = "true" ]; do
    echo "Creating intermediate CA instance"
        if [ ! "${INTERMEDIATE_CA_STATUS}" = "Running" ]; then
            sleep 5
            INTERMEDIATE_CA_STATUS=$(kubectl get pods -n $NAMESPACE | grep intermediate-ca | awk '{print $3}')
        else
            echo "Intermediate CA instance created"
            INTERMEDIATE_CA_CREATING="false"
        fi
done

# Generate Network artifacts using configtx.yaml and crypto-config.yaml
echo -e "\nGenerating the required artifacts for Blockchain network"
echo "Running: kubectl create -n $NAMESPACE -f ${KUBECONFIG_FOLDER}/generate-artifacts-job.yaml"
kubectl create -n $NAMESPACE -f ${KUBECONFIG_FOLDER}/generate-artifacts-job.yaml

JOBSTATUS=$(kubectl get jobs -n $NAMESPACE |grep utils|awk '{print $2}')
while [ "${JOBSTATUS}" != "1/1" ]; do
    echo "Waiting for generateArtifacts job to complete"
    sleep 1;
    # UTILSLEFT=$(kubectl get pods -n $NAMESPACE | grep utils | awk '{print $2}')
    UTILSSTATUS=$(kubectl get pods -n $NAMESPACE | grep "utils" | awk '{print $3}')
    if [ "${UTILSSTATUS}" == "Error" ]; then
            echo "There is an error in utils job. Please check logs."
            exit 1
    fi
    # UTILSLEFT=$(kubectl get pods -n $NAMESPACE | grep utils | awk '{print $2}')
    JOBSTATUS=$(kubectl get jobs -n $NAMESPACE | grep utils| awk '{print $2}')
done

# Create services for all peers, ca, orderer
echo -e "\nCreating Services for blockchain network"
echo "Running: kubectl create -n $NAMESPACE -f ${KUBECONFIG_FOLDER}/blockchain-services.yaml"
kubectl create -n $NAMESPACE -f ${KUBECONFIG_FOLDER}/blockchain-services.yaml


# Create peers, ca, orderer using Kubernetes Deployments
echo -e "\nCreating new Deployment to create the peer in network"
echo "Running: kubectl create -n $NAMESPACE -f ${KUBECONFIG_FOLDER}/orderer-peer-deployment.yaml"
kubectl create -n $NAMESPACE -f ${KUBECONFIG_FOLDER}/orderer-peer-deployment.yaml

echo "Checking if all deployments are ready"

# NUMPENDING=$(kubectl get deployments | grep blockchain | awk '{print $5}' | grep 0 | wc -l | awk '{print $1}')
# while [ "${NUMPENDING}" != "0" ]; do
#     echo "Waiting on pending deployments. Deployments pending = ${NUMPENDING}"
#     NUMPENDING=$(kubectl get deployments | grep blockchain | awk '{print $5}' | grep 0 | wc -l | awk '{print $1}')
#     sleep 1
# done

echo "Waiting for 30 seconds for peer and orderer to settle"
sleep 30


# Generate channel artifacts using configtx.yaml and then create channel
echo -e "\nCreating channel transaction artifact and a channel"
echo "Running: kubectl create -n $NAMESPACE -f ${KUBECONFIG_FOLDER}/setup-channel.yaml"
kubectl create -n $NAMESPACE -f ${KUBECONFIG_FOLDER}/setup-channel.yaml

JOBSTATUS=$(kubectl get jobs -n $NAMESPACE | grep createchannel | awk '{print $2}')
while [ "${JOBSTATUS}" != "1/1" ]; do
    echo "Waiting for createchannel job to be completed"
    sleep 1;
    if [ "$(kubectl get pods -n $NAMESPACE | grep createchannel | awk '{print $3}')" == "Error" ]; then
        echo "Create Channel Failed"
        exit 1
    fi
    JOBSTATUS=$(kubectl get jobs -n $NAMESPACE | grep createchannel | awk '{print $2}')
done
echo "Create Channel Completed Successfully"

echo -e "\nCongratulations! Network setup completed!"
