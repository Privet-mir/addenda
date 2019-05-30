#!/bin/bash

echo -e "\e[34m Fabric Peer cli \e[0m"

helm install -n org1cli ../cli --namespace org1 -f ./helm_values/org1cli.yaml

sleep 60
org1_POD=$(kubectl get pods --namespace org1 -l "app=addenda,release=org1cli" -o jsonpath="{.items[0].metadata.name}")
kubectl logs -n org1 $org1_POD | grep 'Starting peer'

kubectl exec -n org1 $org1_POD -- bash -c 'CORE_PEER_MSPCONFIGPATH=$ADMIN_MSP_PATH CORE_PEER_LOCALMSPID=Org1MSP CORE_PEER_ID=peer1 peer channel create -o addenda1-orderer.orderer.svc.cluster.local:7050 -c addenda-channel -f /hl_config/channel/addenda-channel.tx'

kubectl  exec -n org1 $org1_POD -- bash -c 'CORE_PEER_MSPCONFIGPATH=$ADMIN_MSP_PATH CORE_PEER_LOCALMSPID=Org1MSP CORE_PEER_ID=peer1 peer channel fetch config /var/hyperledger/addenda-channel.block -c addenda-channel -o addenda1-orderer.orderer.svc.cluster.local:7050'

kubectl  exec -n org1 $org1_POD -- bash -c 'CORE_PEER_MSPCONFIGPATH=$ADMIN_MSP_PATH CORE_PEER_LOCALMSPID=Org1MSP CORE_PEER_ID=peer1 peer channel join -b /var/hyperledger/addenda-channel.block'

echo "\e[34m For peer2 to join channel we have to use peer2 pod, because CLI is configured with peer1 to use it for peer2 we only need to configure peer2 MSP on CLI\e[0m"

PEER_POD=$(kubectl get pods --namespace org1 -l "app=addenda,release=peer2" -o jsonpath="{.items[0].metadata.name}")

kubectl  exec -n org1 $PEER_POD -- bash -c 'CORE_PEER_MSPCONFIGPATH=$ADMIN_MSP_PATH peer channel fetch newest /var/hyperledger/addenda-channel.block -c addenda-channel -o addenda1-orderer.orderer.svc.cluster.local:7050'

kubectl  exec -n org1 $PEER_POD -- bash -c 'CORE_PEER_MSPCONFIGPATH=$ADMIN_MSP_PATH peer channel join -b /var/hyperledger/addenda-channel.block'