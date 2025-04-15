#!/bin/bash

# chaincode_lifecycle.sh - Automates chaincode deployment for all 4 orgs

set -e

# ----------- CONFIG ----------- 
CC_NAME="supplychain"
CC_LABEL="supplychain_1"
CC_VERSION="1.0"
CC_SEQUENCE=2   # Sequence must be incremented for the next commit
CC_PATH="/home/harshil/fabric/supply-chain-management-using-hyperledger-fabric/chaincode/supplychain/go"   # Correct path to chaincode
CHANNEL_NAME="supplychain-channel"
INIT_REQUIRED="--init-required"
ORDERER_CA="../supplychain-network/organizations/ordererOrganizations/supplychain.com/orderers/orderer.supplychain.com/msp/tlscacerts/tlsca.supplychain.com-cert.pem"

PEER_CONN_ARGS=""
PACKAGE_ID=""

# ----------- FUNCTIONS -----------

setGlobals() {
  ORG=$1
  PEER_PORT=$2
  MSP_ID=$3

  export CORE_PEER_LOCALMSPID="$MSP_ID"
  export CORE_PEER_TLS_ROOTCERT_FILE=/home/harshil/fabric/supply-chain-management-using-hyperledger-fabric/supplychain-network/organizations/peerOrganizations/$ORG.supplychain.com/peers/peer0.$ORG.supplychain.com/tls/ca.crt
  export CORE_PEER_MSPCONFIGPATH=/home/harshil/fabric/supply-chain-management-using-hyperledger-fabric/supplychain-network/organizations/peerOrganizations/$ORG.supplychain.com/users/Admin@$ORG.supplychain.com/msp
  export CORE_PEER_ADDRESS=localhost:$PEER_PORT
}

packageChaincode() {
  # The correct path to package chaincode
  peer lifecycle chaincode package ${CC_NAME}.tar.gz --path ${CC_PATH} --lang golang --label ${CC_LABEL}
}

installChaincode() {
  # Installing chaincode on all peers
  echo "🔧 Installing chaincode on Peer0 of IndonesianFarmOrg1..."
  setGlobals indonesianfarmorg1 7051 IndonesianFarmOrg1MSP
  peer lifecycle chaincode install ${CC_NAME}.tar.gz

  echo "🔧 Installing chaincode on Peer0 of USClientOrg2..."
  setGlobals usclientorg2 9051 USClientOrg2MSP
  peer lifecycle chaincode install ${CC_NAME}.tar.gz

  echo "🔧 Installing chaincode on Peer0 of RubberShipperOrg3..."
  setGlobals rubbershipperorg3 11051 RubberShipperOrg3MSP
  peer lifecycle chaincode install ${CC_NAME}.tar.gz

  echo "🔧 Installing chaincode on Peer0 of GoodsCustomOrg4..."
  setGlobals goodscustomorg4 13051 GoodsCustomOrg4MSP
  peer lifecycle chaincode install ${CC_NAME}.tar.gz
}

queryInstalled() {
  # Query installed chaincode to get PACKAGE_ID
  setGlobals indonesianfarmorg1 7051 IndonesianFarmOrg1MSP
  peer lifecycle chaincode queryinstalled > log.txt
  PACKAGE_ID=$(sed -n "/${CC_LABEL}/s/Package ID: //p" log.txt | awk '{print $1}')
  echo "PACKAGE_ID is $PACKAGE_ID"
}

approveForOrg() {
  ORG=$1
  PORT=$2
  MSP=$3
  setGlobals $ORG $PORT $MSP

  echo "✅ Approving chaincode for $ORG..."
  peer lifecycle chaincode approveformyorg \
    --channelID $CHANNEL_NAME \
    --name $CC_NAME \
    --version $CC_VERSION \
    --package-id $PACKAGE_ID \
    --sequence $CC_SEQUENCE \
    $INIT_REQUIRED \
    --tls \
    --cafile $ORDERER_CA \
    --orderer localhost:7050
}

commitChaincode() {
  # Commit chaincode
  setGlobals indonesianfarmorg1 7051 IndonesianFarmOrg1MSP

  PEER_CONN_ARGS="--peerAddresses localhost:7051 \
    --tlsRootCertFiles $BASE_DIR/supplychain-network/organizations/peerOrganizations/indonesianfarmorg1.supplychain.com/peers/peer0.indonesianfarmorg1.supplychain.com/tls/ca.crt \
    --peerAddresses localhost:9051 \
    --tlsRootCertFiles $BASE_DIR/supplychain-network/organizations/peerOrganizations/usclientorg2.supplychain.com/peers/peer0.usclientorg2.supplychain.com/tls/ca.crt \
    --peerAddresses localhost:11051 \
    --tlsRootCertFiles $BASE_DIR/supplychain-network/organizations/peerOrganizations/rubbershipperorg3.supplychain.com/peers/peer0.rubbershipperorg3.supplychain.com/tls/ca.crt \
    --peerAddresses localhost:13051 \
    --tlsRootCertFiles $BASE_DIR/supplychain-network/organizations/peerOrganizations/goodscustomorg4.supplychain.com/peers/peer0.goodscustomorg4.supplychain.com/tls/ca.crt"

  echo "🧾 Committing chaincode..."
  peer lifecycle chaincode commit \
    --channelID $CHANNEL_NAME \
    --name $CC_NAME \
    --version $CC_VERSION \
    --sequence $CC_SEQUENCE \
    $INIT_REQUIRED \
    --tls \
    --cafile $ORDERER_CA \
    --orderer localhost:7050 \
    $PEER_CONN_ARGS
}

initChaincode() {
  # Initialize chaincode
  peer chaincode invoke \
    -o localhost:7050 \
    --ordererTLSHostnameOverride orderer.supplychain.com \
    --tls \
    --cafile $ORDERER_CA \
    -C $CHANNEL_NAME \
    -n $CC_NAME \
    --isInit \
    -c '{"Args":["InitLedger"]}'
}

# ----------- EXECUTION -----------

echo "🔧 Packaging chaincode..."
packageChaincode

echo "📥 Installing chaincode on all peers..."
installChaincode

echo "🔍 Querying installed chaincode..."
queryInstalled

echo "✅ Approving chaincode for all orgs..."
approveForOrg indonesianfarmorg1 7051 IndonesianFarmOrg1MSP
approveForOrg usclientorg2 9051 USClientOrg2MSP
approveForOrg rubbershipperorg3 11051 RubberShipperOrg3MSP
approveForOrg goodscustomorg4 13051 GoodsCustomOrg4MSP

echo "🧾 Committing chaincode..."
commitChaincode

echo "🚀 Initializing chaincode..."
initChaincode

echo "✅ All Done. Chaincode '$CC_NAME' deployed and initialized successfully."
