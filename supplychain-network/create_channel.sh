#!/bin/bash

# ✅ Set the correct FABRIC_CFG_PATH (important fix)
echo "📂 FABRIC_CFG_PATH is set to: $FABRIC_CFG_PATH"


source ../terminal_control.sh

export CORE_PEER_TLS_ENABLED=true
export ORDERER_CA=${PWD}/organizations/ordererOrganizations/supplychain.com/orderers/orderer.supplychain.com/msp/tlscacerts/tlsca.supplychain.com-cert.pem
export CHANNEL_NAME=supplychain-channel

#############################################
# 🌍 ENV VARS for each org/peer
#############################################

setEnvForPeer() {
    ORG=$1
    PEER=$2
    PORT=$3

    export CORE_PEER_LOCALMSPID=${ORG}MSP
    export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/$(echo $ORG | tr '[:upper:]' '[:lower:]').supplychain.com/peers/peer${PEER}.$(echo $ORG | tr '[:upper:]' '[:lower:]').supplychain.com/tls/ca.crt
    export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/$(echo $ORG | tr '[:upper:]' '[:lower:]').supplychain.com/users/Admin@$(echo $ORG | tr '[:upper:]' '[:lower:]').supplychain.com/msp
    export CORE_PEER_ADDRESS=localhost:${PORT}
}

#############################################
# 📦 Create Channel
#############################################
createChannel() {
    setEnvForPeer IndonesianFarmOrg1 0 7051

    print Green "========== Creating Channel =========="
    peer channel create \
        -o localhost:7050 \
        --ordererTLSHostnameOverride orderer.supplychain.com \
        -c $CHANNEL_NAME \
        -f ./channel-artifacts/$CHANNEL_NAME.tx \
        --outputBlock ./channel-artifacts/${CHANNEL_NAME}.block \
        --tls --cafile $ORDERER_CA
    echo ""
}

#############################################
# 🔗 Join Peers to Channel
#############################################
joinChannel() {
    declare -A PEER_PORTS=(
        [IndonesianFarmOrg1_0]=7051
        [IndonesianFarmOrg1_1]=8051
        [USClientOrg2_0]=9051
        [USClientOrg2_1]=10051
        [RubberShipperOrg3_0]=11051
        [RubberShipperOrg3_1]=12051
        [GoodsCustomOrg4_0]=13051
        [GoodsCustomOrg4_1]=14051
    )

    for PEER_ID in "${!PEER_PORTS[@]}"; do
        ORG=$(echo $PEER_ID | cut -d_ -f1)
        IDX=$(echo $PEER_ID | cut -d_ -f2)
        PORT=${PEER_PORTS[$PEER_ID]}

        setEnvForPeer $ORG $IDX $PORT
        print Green "========== ${ORG} Peer${IDX} Joining Channel '$CHANNEL_NAME' =========="
        peer channel join -b ./channel-artifacts/$CHANNEL_NAME.block
        echo ""
    done
}

#############################################
# 📡 Update Anchor Peers
#############################################
updateAnchorPeers() {
    declare -A ANCHORS=(
        [IndonesianFarmOrg1]=7051
        [USClientOrg2]=9051
        [RubberShipperOrg3]=11051
        [GoodsCustomOrg4]=13051
    )

    for ORG in "${!ANCHORS[@]}"; do
        PORT=${ANCHORS[$ORG]}
        setEnvForPeer $ORG 0 $PORT

        print Green "========== Updating Anchor Peer of $ORG =========="
        peer channel update \
            -o localhost:7050 \
            --ordererTLSHostnameOverride orderer.supplychain.com \
            -c $CHANNEL_NAME \
            -f ./channel-artifacts/${CORE_PEER_LOCALMSPID}Anchor.tx \
            --tls --cafile $ORDERER_CA
        echo ""
    done
}

#############################################
# 🚀 Execute All
#############################################
createChannel
joinChannel
updateAnchorPeers
