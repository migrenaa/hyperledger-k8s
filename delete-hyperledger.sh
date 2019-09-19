#!/bin/bash 

NAMESPACE=""

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
            echo "Namespace \"$ns\" exists. Resources will be removed from there." 
            NAMESPACE=$ns
        fi
    done
    
    if [ -z $NAMESPACE ]; then
        echo "Namespace \"$1\" does not exist"
        exit
    fi  
else
    echo "You must specify a namespace as an argument."
    exit
fi

############ DELETE KAFKA AND ZOOKEEPER ##############

kubectl delete -n $NAMESPACE -f ${KUBECONFIG_FOLDER}/zookeeper.yaml

kubectl delete -n $NAMESPACE -f ${KUBECONFIG_FOLDER}/kafka.yaml

############# DELETING NETWORK #############

kubectl delete -n $NAMESPACE --ignore-not-found=true -f ${KUBECONFIG_FOLDER}/docker.yaml

kubectl delete -n $NAMESPACE -f ${KUBECONFIG_FOLDER}/orderer-peer-deployment.yaml
kubectl delete -n $NAMESPACE -f ${KUBECONFIG_FOLDER}/blockchain-services.yaml

kubectl delete -n $NAMESPACE -f ${KUBECONFIG_FOLDER}/generate-artifacts-job.yaml
kubectl delete -n $NAMESPACE -f ${KUBECONFIG_FOLDER}/copy-artifacts-job.yaml

kubectl delete -n $NAMESPACE -f ${KUBECONFIG_FOLDER}/createVolume.yaml
kubectl delete -n $NAMESPACE --ignore-not-found=true -f ${KUBECONFIG_FOLDER}/docker-volume.yaml

kubectl delete -n $NAMESPACE -f ${KUBECONFIG_FOLDER}/ca-deployment.yaml
kubectl delete -n $NAMESPACE -f ${KUBECONFIG_FOLDER}/setup-channel.yaml

sleep 30

echo -e "\npv:" 
kubectl get pv -n $NAMESPACE
echo -e "\npvc:"
kubectl get pvc -n $NAMESPACE
echo -e "\njobs:"
kubectl get jobs -n $NAMESPACE
echo -e "\ndeployments:"
kubectl get deployments -n $NAMESPACE
echo -e "\nservices:"
kubectl get services -n $NAMESPACE
echo -e "\npods:"
kubectl get pods -n $NAMESPACE

echo -e "\nNetwork deleted!\n"
