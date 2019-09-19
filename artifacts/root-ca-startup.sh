#!/bin/bash

function startCAServer {
    # Initialize the root CA
    fabric-ca-server init -b $BOOTSTRAP_USER_PASS
    # Copy the root CA's signing certificate to the data directory to be used by others
    cp $FABRIC_CA_SERVER_HOME/ca-cert.pem $TARGET_CERTFILE
    # Start the root CA
    fabric-ca-server start
}

startCAServer