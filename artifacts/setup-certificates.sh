#!/bin/bash

# TODO move in yaml file
export ROOT_CA_CERTFILE=/shared/testorg-ca-cert.pem
export INT_CA_CHAINFILE=/shared/testorg-ca-chain.pem
export ORG_MSP_ID=testorgMSP
export ORG_MSP_DIR=/shared/testorg/msp
export ORG_ADMIN_CERT=/shared/testorg/msp/admincerts/cert.pem
export ORG_ADMIN_HOME=/shared/testorg/admin
export CA_NAME=intermediate-ca-testorg

function registerIdentities {
  echo "Enrolling CA Admin.." 
  enrollCAAdmin
  echo "CA admin enrolled.."
  echo "Registering orderer identities.. "
  registerOrdererIdentities
  echo "Registering peer identities.. "
  registerPeerIdentities
  echo "Register identities finished.."
}

# Register any identities associated with the orderer
function registerOrdererIdentities {
  fabric-ca-client register -d --id.name $ORDERER_NAME --id.secret $ORDERER_PASS --id.type orderer
  fabric-ca-client register -d --id.name $ADMIN_NAME --id.secret $ADMIN_PASS --id.attrs '"hf.Registrar.Roles=client,peer",hf.Registrar.Attributes=*,hf.Revoker=true,hf.GenCRL=true,admin=true:ecert,abac.init=true:ecert'
  echo "Register orderer identities finished"
}

# Register any identities associated with a peer
function registerPeerIdentities {
  fabric-ca-client register -d --id.name $PEER_NAME --id.secret $PEER_PASS --id.type peer
  fabric-ca-client register -d --id.name $USER_NAME --id.secret $USER_PASS
  echo "Register peer identities finished"
}

function getCACerts {
  fabric-ca-client getcacert -d -u http://$CA_HOST -M ${ORG_MSP_DIR}
  # Stored root CA certificate at /shared/testorg/msp/cacerts/blockchain-intermediate-ca-30055.pem
  switchToAdminIdentity
  echo "Get CA certs finished..."
}


# Enroll the CA administrator
function enrollCAAdmin {
  echo "Enrolling CA admin identity.."
  export FABRIC_CA_CLIENT_HOME=$HOME/cas/$CA_NAME
  fabric-ca-client enroll -d -u http://$CA_ADMIN_NAME:$CA_ADMIN_PASS@$CA_HOST
  echo "Enrolling CA admin identity.."
}

# Switch to the current org's admin identity.  Enroll if not previously enrolled.
function switchToAdminIdentity {
  if [ ! -d $ORG_ADMIN_HOME ]; then
    export FABRIC_CA_CLIENT_HOME=$ORG_ADMIN_HOME
    fabric-ca-client enroll -d -u http://$ADMIN_NAME:$ADMIN_PASS@$CA_HOST
    # If admincerts are required in the MSP, copy the cert there now and to my local MSP also
    mkdir -p $(dirname "${ORG_ADMIN_CERT}")
    # TODO move in env var
    cp /shared/testorg/admin/msp/signcerts/* $ORG_ADMIN_CERT
    # cp $ORG_ADMIN_HOME/msp/signcerts/* $ORG_ADMIN_CERT
    mkdir $ORG_ADMIN_HOME/msp/admincerts
    cp $ORG_ADMIN_HOME/msp/signcerts/* $ORG_ADMIN_HOME/msp/admincerts
  fi
  export CORE_PEER_MSPCONFIGPATH=$ORG_ADMIN_HOME/msp
}

function generateChannelArtifacts() {
  which configtxgen
  if [ "$?" -ne 0 ]; then
    echo "configtxgen tool not found. exiting"
    exit 1
  fi

  echo "Generating orderer genesis block at $GENESIS_BLOCK_FILE"

  cp $CONFIG_TX_FILE /etc/hyperledger/fabric/configtx.yaml
  
  # The certificates are stored in the shared folder. configtxgen is looking for them in the etc/hyperledger/fabric msp folder.
  mkdir -p /etc/hyperledger/fabric/shared/testorg/msp
  cp /shared/testorg/msp/* /etc/hyperledger/fabric/shared/testorg/msp/ -r

  configtxgen -profile OrgOrdererGenesis -outputBlock $GENESIS_BLOCK_FILE 
  if [ "$?" -ne 0 ]; then
    echo "Failed to generate orderer genesis block"
    exit 1
  fi

  echo "Generating channel configuration transaction at $CHANNEL_TX_FILE"
  configtxgen -profile OrgChannel -outputCreateChannelTx $CHANNEL_TX_FILE -channelID $CHANNEL_NAME
  if [ "$?" -ne 0 ]; then
    echo "Failed to generate channel configuration transaction"
    exit 1
  fi

  echo "Generating anchor peer update transaction for $ORG at $ANCHOR_TX_FILE"
  configtxgen -profile OrgChannel -outputAnchorPeersUpdate $ANCHOR_TX_FILE \
    -channelID $CHANNEL_NAME -asOrg $ORG
  if [ "$?" -ne 0 ]; then
    echo "Failed to generate anchor peer update for $ORG"
  fi
}

# while [ ! -f /shared/itermediate-started ]; 
# do echo "Waiting for intermediate CA to start";
# done

# rm /shared/intermediate-started

registerIdentities
echo "Creating cert
ificates process finished..."
sleep 10
getCACerts
echo "Getting CA certs finished..."
echo "Waiting for 10 more seconds for getting certificates to avoid any network delay.. "
sleep 10
generateChannelArtifacts
echo "Generating channel artifacts process finished.."
