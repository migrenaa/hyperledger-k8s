#!/bin/bash

# Enroll the peer to get an enrollment certificate and set up the core's local MSP directory
mkdir -p $CORE_PEER_MSPCONFIGPATH
fabric-ca-client enroll -d -u $ENROLLMENT_URL -M $CORE_PEER_MSPCONFIGPATH
dstDir=$CORE_PEER_MSPCONFIGPATH/admincerts
mkdir -p $dstDir
cp $ORG_ADMIN_CERT $dstDir

peer node start
