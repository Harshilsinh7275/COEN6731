#!/bin/bash

# Chaincode Deployment Script for ALL 4 ORGs

set -e

CC_NAME="supplychain"
CC_LABEL="supplychain_1"
CC_VERSION="1.0"
CC_SEQUENCE=1
CC_PATH="../chaincode/supplychain/go"
CHANNEL_NAME="supplychain-channel"
INIT_REQUIRED="--init-required"
ORDERER_CA="organizations/ordererOrganizations/supplychain.com/orderers/orderer.supplychain.com/msp/tlscacerts/tlsca.supplychain.com-cert.pem"

setGlobals() {
  ORG=$1
  PORT=$2
  MSP=$3

  export CORE_PEER_LOCALMSPID=$MSP
  export CORE_PEER_TLS_ROOTCERT_FILE=$PWD/organizations/peerOrganizations/$ORG.supplychain.com/peers/peer0.$ORG.supplychain.com/tls/ca.crt
  export CORE_PEER_MSPCONFIGPATH=$PWD/organizations/peerOrganizations/$ORG.supplychain.com/users/Admin@$ORG.supplychain.com/msp
  export CORE_PEER_ADDRESS=localhost:$PORT
}

packageChaincode() {
  peer lifecycle chaincode package ${CC_NAME}.tar.gz \
    --path ${CC_PATH} --lang golang --label ${CC_LABEL}
}

installChaincode() {
  setGlobals indonesianfarmorg1 7051 IndonesianFarmOrg1MSP
  peer lifecycle chaincode install ${CC_NAME}.tar.gz

  setGlobals usclientorg2 9051 USClientOrg2MSP
  peer lifecycle chaincode install ${CC_NAME}.tar.gz

  setGlobals rubbershipperorg3 11051 RubberShipperOrg3MSP
  peer lifecycle chaincode install ${CC_NAME}.tar.gz

  setGlobals goodscustomorg4 13051 GoodsCustomOrg4MSP
  peer lifecycle chaincode install ${CC_NAME}.tar.gz
}

queryInstalled() {
  setGlobals indonesianfarmorg1 7051 IndonesianFarmOrg1MSP
  peer lifecycle chaincode queryinstalled > log.txt
  PACKAGE_ID=$(sed -n "/${CC_LABEL}/s/Package ID: //p" log.txt | awk '{print $1}')
  echo "📦 Extracted PACKAGE_ID: $PACKAGE_ID"
}

approveForOrg() {
  ORG=$1
  PORT=$2
  MSP=$3
  setGlobals $ORG $PORT $MSP

  peer lifecycle chaincode approveformyorg \
    --channelID $CHANNEL_NAME \
    --name $CC_NAME \
    --version $CC_VERSION \
    --package-id $PACKAGE_ID \
    --sequence $CC_SEQUENCE \
    $INIT_REQUIRED \
    --tls \
    --cafile $ORDERER_CA
}

commitChaincode() {
  setGlobals indonesianfarmorg1 7051 IndonesianFarmOrg1MSP
  peer lifecycle chaincode commit \
    --channelID $CHANNEL_NAME \
    --name $CC_NAME \
    --version $CC_VERSION \
    --sequence $CC_SEQUENCE \
    $INIT_REQUIRED \
    --tls \
    --cafile $ORDERER_CA \
    --peerAddresses localhost:7051 --tlsRootCertFiles $PWD/organizations/peerOrganizations/indonesianfarmorg1.supplychain.com/peers/peer0.indonesianfarmorg1.supplychain.com/tls/ca.crt \
    --peerAddresses localhost:9051 --tlsRootCertFiles $PWD/organizations/peerOrganizations/usclientorg2.supplychain.com/peers/peer0.usclientorg2.supplychain.com/tls/ca.crt \
    --peerAddresses localhost:11051 --tlsRootCertFiles $PWD/organizations/peerOrganizations/rubbershipperorg3.supplychain.com/peers/peer0.rubbershipperorg3.supplychain.com/tls/ca.crt \
    --peerAddresses localhost:13051 --tlsRootCertFiles $PWD/organizations/peerOrganizations/goodscustomorg4.supplychain.com/peers/peer0.goodscustomorg4.supplychain.com/tls/ca.crt
}

initChaincode() {
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

echo "📦 Packaging..."
packageChaincode

echo "📥 Installing on all orgs..."
installChaincode

echo "🔍 Querying installed package..."
queryInstalled

echo "✅ Approving chaincode for all orgs..."
approveForOrg indonesianfarmorg1 7051 IndonesianFarmOrg1MSP
approveForOrg usclientorg2 9051 USClientOrg2MSP
approveForOrg rubbershipperorg3 11051 RubberShipperOrg3MSP
approveForOrg goodscustomorg4 13051 GoodsCustomOrg4MSP

echo "📡 Committing chaincode..."
commitChaincode

echo "🚀 Initializing chaincode..."
initChaincode

echo "✅ All steps complete!"
