#!/bin/bash

# Initialize the intermediate CA

# while [ ! -f /shared/root-started ]; 
# do echo "Waiting for root CA to start";
# done

function startCAServer {
    fabric-ca-server init -b $BOOTSTRAP_USER_PASS -u $PARENT_URL
    # Copy the intermediate CA's certificate chain to the data directory to be used by others
    cp $FABRIC_CA_SERVER_HOME/ca-chain.pem $TARGET_CHAINFILE
    # Start the intermediate CA
    fabric-ca-server start
}

startCAServer
