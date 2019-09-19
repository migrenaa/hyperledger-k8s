
# !/bin/bash

export POLICY="OR('testorgMSP.member')"

# Enroll as a peer admin and create the channel
function createChannel {
  echo "Creating channel $CHANNEL_NAME..."
  peer channel create --logging-level=INFO -c $CHANNEL_NAME -f $CHANNEL_TX_FILE -o $ORDERER_URL

  # Save channel block so that additional peers can join later
  cp /$CHANNEL_NAME.block /shared/
  echo "Channel created."
}

# Enroll as a fabric admin and join the channel
function joinChannel {
  local COUNT=1
  MAX_RETRY=10
  while true; do
    echo "Peer $PEER_HOST is attempting to join channel '$CHANNEL_NAME' (attempt #${COUNT}) ..."
    peer channel join -b /shared/$CHANNEL_NAME.block

    if [ $? -eq 0 ]; then
      set -e
      echo "Peer $PEER_HOST successfully joined channel '$CHANNEL_NAME'"
      return
    fi
    if [ $COUNT -gt $MAX_RETRY ]; then
      echo "Peer $PEER_HOST failed to join channel '$CHANNEL_NAME' in $MAX_RETRY retries"
      exit 1
    fi
    COUNT=$((COUNT+1))
    sleep 1
  done
}

# Peer
# Update the anchor peers
function updateAnchorPeers {
  echo "Updating anchor peers for $PEER_HOST ..."
  peer channel update -c $CHANNEL_NAME -f $ANCHOR_TX_FILE -o $ORDERER_URL
}


function installChaincodes {
  echo "Installing chaincodes on $CORE_PEER_ADDRESS ..."
  go get github.com/golang/protobuf/proto
  go get github.com/hyperledger/fabric/protos/msp
  go get github.com/hyperledger/fabric/core/chaincode/lib/cid
  go get github.com/pkg/errors
  cp -r $CHAINCODE_FOLDER/* $GOPATH/src/
  peer chaincode install -n $CHAINCODE_NAME -v $CHAINCODE_VERSION -p $CHAINCODE_NAME/
}

function instantiateChaincodes {
  peer chaincode instantiate -C $CHANNEL_NAME -n $CHAINCODE_NAME -v $CHAINCODE_VERSION -P "$POLICY" -c "{\"Args\": [\"\"]}" -o $ORDERER_URL

}

# Create the channel
createChannel
sleep 10
joinChannel
sleep 10
updateAnchorPeers 
sleep 10
installChaincodes
sleep 10
instantiateChaincodes
sleep 10

# TEST
peer chaincode invoke -C $CHANNEL_NAME -n test-cc -c '{"Args":["storeRestorationCode","12123123132","asdasd"]}' -o blockchain-orderer:31010
sleep 10