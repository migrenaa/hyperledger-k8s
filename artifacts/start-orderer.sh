#!/bin/bash

function start { 
    fabric-ca-client enroll -d -u $ENROLLMENT_URL -M $ORDERER_GENERAL_LOCALMSPDIR
    sleep 10
    copyAdminCert
    # dstDir=$ORDERER_GENERAL_LOCALMSPDIR/admincerts
    # mkdir -p $dstDir
    # cp $ORG_ADMIN_CERT $dstDir
    orderer
}


# Copy the org's admin cert into some target MSP directory
# This is only required if ADMINCERTS is enabled.
function copyAdminCert {
#   if [ $# -ne 1 ]; then
#     FATAL "Usage: copyAdminCert <targetMSPDIR>"
#     exit 1
#   fi
  dstDir=$ORDERER_GENERAL_LOCALMSPDIR/admincerts
  mkdir -p $dstDir
  cp $ORG_ADMIN_CERT $dstDir
}

start