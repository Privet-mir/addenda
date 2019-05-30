#!/bin/bash

cd /artifacts

export CORE_PEER_LOCALMSPID=Org1MSP
export CORE_PEER_MSPCONFIGPATH=/var/hyperledger/admin_msp 
export CONFIGTXLATOR_URL=http://127.0.0.1:7059
export CHANNEL_NAME=addenda-channel
export CORE_PEER_ID=peer1
configtxlator start &

peer channel fetch config config_block.pb -o addenda1-orderer.orderer.svc.cluster.local:7050 -c $CHANNEL_NAME

curl -X POST --data-binary @config_block.pb $CONFIGTXLATOR_URL/protolator/decode/common.Block > config_block.json

jq .data.data[0].payload.data.config config_block.json > config.json

jq -s '.[0] * {"channel_group": {"groups": {"Application": {"groups":{ "Org2MSP":.[1]}}}}}' config.json org2.json >& updated_config.json

curl -X POST --data-binary @config.json $CONFIGTXLATOR_URL/protolator/encode/common.Config > config.pb

curl -X POST --data-binary @updated_config.json $CONFIGTXLATOR_URL/protolator/encode/common.Config > updated_config.pb

curl -X POST -F original=@config.pb -F updated=@updated_config.pb $CONFIGTXLATOR_URL/configtxlator/compute/update-from-configs -F channel=$CHANNEL_NAME > config_update.pb

curl -X POST --data-binary @config_update.pb $CONFIGTXLATOR_URL/protolator/decode/common.ConfigUpdate > config_update.json

echo '{"payload":{"header":{"channel_header":{"channel_id":"'$CHANNEL_NAME'","type": 2}},"data":{"config_update":'$(cat config_update.json)'}}}' >config_update_as_envelope.json

curl -X POST --data-binary @config_update_as_envelope.json $CONFIGTXLATOR_URL/protolator/encode/common.Envelope > config_update_as_envelope.pb

peer channel signconfigtx -f config_update_as_envelope.pb

peer channel update -f config_update_as_envelope.pb -o addenda1-orderer.orderer.svc.cluster.local:7050 -c $CHANNEL_NAME