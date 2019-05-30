#!/bin/bash

NUM=$1

for i in $(seq 1 $NUM)
do
echo -e "\e[34m Fabric Peer$i \e[0m"

echo -e "\e[34m Install CouchDB chart \e[0m"
helm install -n addenda-couchdb${i} ../addenda-couchdb/ --namespace org1 -f ./helm_values/cdb-peer${i}.yaml
sleep 70

CDB_POD=$(kubectl get pods -n org1 -l "app=couchdb,release=addenda-couchdb${i}" -o jsonpath="{.items[*].metadata.name}")

kubectl logs -n org1 $CDB_POD | grep 'Apache CouchDB has started on'

CA_POD=$(kubectl get pods -n cas -l "app=addenda,release=ca" -o jsonpath="{.items[0].metadata.name}")

CA_INGRESS=$(kubectl get ingress -n cas -l "app=addenda,release=ca" -o jsonpath="{.items[0].spec.rules[0].host}")


echo -e "\e[34m Register peer with CA \e[0m"
kubectl exec -n cas $CA_POD -- fabric-ca-client register --id.name peer${i} --id.secret peer${i}_pw --id.type peer
FABRIC_CA_CLIENT_HOME=./config fabric-ca-client enroll -d -u https://peer${i}:peer${i}_pw@$CA_INGRESS -M org1peer${i}_MSP
echo -e "\e[34m Save the Peer certificate in a secret \e[0m"
NODE_CERT=$(ls ./config/org1peer${i}_MSP/signcerts/*.pem)
kubectl create secret generic -n org1 hlf--peer${i}-idcert --from-file=cert.pem=${NODE_CERT}
echo -e "\e[34m Save the Peer private key in another secret \e[0m"
NODE_KEY=$(ls ./config/org1peer${i}_MSP/keystore/*_sk)
kubectl create secret generic -n org1 hlf--peer${i}-idkey --from-file=key.pem=${NODE_KEY}

echo -e "\e[34m Install Fabric Peer Chart \e[0m"
helm install -n peer${i} ../addenda-peer --namespace org1 -f ./helm_values/peer${i}.yaml
sleep 60
PEER_POD=$(kubectl get pods --namespace org1 -l "app=addenda,release=peer${i}" -o jsonpath="{.items[0].metadata.name}")
kubectl logs -n org1 $PEER_POD | grep 'Starting peer'

done