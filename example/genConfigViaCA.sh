#!/bin/bash

echo -e "\e[34m Complete Deployment takes 15-20 min\e[0m"

echo -e "\e[34m Creating Namespaces\e[0m"
kubectl create ns cas
kubectl create ns orderer
kubectl create ns org1

echo -e "\e[34m Install CA\e[0m"
helm install ../addenda-ca -n ca --namespace cas -f ./helm_values/ca.yaml
echo -e "\e[34m Please be Patient CA is getting installed it migth take upto 1-2 min\e[0m"
sleep 80
CA_POD=$(kubectl get pods -n cas -l "app=addenda,release=ca" -o jsonpath="{.items[0].metadata.name}")
kubectl logs -n cas $CA_POD | grep "Listening on"

echo -e "\e[34m Enroll admin for CA \e[0m"
kubectl exec -n cas $CA_POD -- bash -c 'fabric-ca-client enroll -d -u http://$CA_ADMIN:$CA_PASSWORD@$SERVICE_DNS:7054'

CA_INGRESS=$(kubectl get ingress -n cas -l "app=addenda,release=ca" -o jsonpath="{.items[0].spec.rules[0].host}")

echo -e "\e[34m Curl CAINFO\e[0m"
curl https://$CA_INGRESS/cainfo

#exit 1
echo -e "\e[34m Register admin identiy for orderer on CA\e[0m"
kubectl exec -n cas $CA_POD -- fabric-ca-client register --id.name ord-admin --id.secret OrdAdm1nPW --id.attrs 'admin=true:ecert'

echo -e "\e[34m Register peer identiy on CA\e[0m"
kubectl exec -n cas $CA_POD -- fabric-ca-client register --id.name peer-admin --id.secret PeerAdm1nPW --id.attrs 'admin=true:ecert'

echo -e "\e[34m Enroll admin identiy orderer on CA\e[0m"
FABRIC_CA_CLIENT_HOME=./config fabric-ca-client enroll -u https://ord-admin:OrdAdm1nPW@$CA_INGRESS -M ./OrdererMSP
mkdir -p ./config/OrdererMSP/admincerts
cp ./config/OrdererMSP/signcerts/* ./config/OrdererMSP/admincerts

echo -e "\e[34m Enroll peer organization admin identiy on CA\e[0m"
FABRIC_CA_CLIENT_HOME=./config fabric-ca-client enroll -u https://peer-admin:PeerAdm1nPW@$CA_INGRESS -M ./Org1MSP
mkdir -p ./config/Org1MSP/admincerts
cp ./config/Org1MSP/signcerts/* ./config/Org1MSP/admincerts

echo -e "\e[34m Create a secret to hold the admin certificate:Orderer Organisation\e[0m"
ORG_CERT=$(ls ./config/OrdererMSP/admincerts/cert.pem)
kubectl create secret generic -n orderer hlf--ord-admincert --from-file=cert.pem=$ORG_CERT
echo -e "\e[34m Create a secret to hold the admin key:Orderer Organisation\e[0m"
ORG_KEY=$(ls ./config/OrdererMSP/keystore/*_sk)
kubectl create secret generic -n orderer hlf--ord-adminkey --from-file=key.pem=$ORG_KEY
echo -e "\e[34m Create a secret to hold the admin key CA certificate:Orderer Organisation\e[0m"
CA_CERT=$(ls ./config/OrdererMSP/cacerts/*.pem)
kubectl create secret generic -n orderer hlf--ord-ca-cert --from-file=cacert.pem=$CA_CERT

echo -e "\e[34m Create a secret to hold the admincert:Peer Organisation\e[0m"
ORG_CERT=$(ls ./config/Org1MSP/admincerts/cert.pem)
kubectl create secret generic -n org1 hlf--peer-admincert --from-file=cert.pem=$ORG_CERT
echo -e "\e[34m Create a secret to hold the admin key:Peer Organisation\e[0m"
ORG_KEY=$(ls ./config/Org1MSP/keystore/*_sk)
kubectl create secret generic -n org1 hlf--peer-adminkey --from-file=key.pem=$ORG_KEY
echo -e "\e[34m Create a secret to hold the CA certificate:Peer Organisation\e[0m"
CA_CERT=$(ls ./config/Org1MSP/cacerts/*.pem)
kubectl create secret generic -n org1 hlf--peer-ca-cert --from-file=cacert.pem=$CA_CERT

echo -e "\e[34m Create Genesis and channel \e[0m"
cd ./config
configtxgen -profile AddendaOrdererGenesis -outputBlock ./genesis.block
configtxgen -profile AddendaChannel -channelID addenda-channel -outputCreateChannelTx ./addenda-channel.tx
echo -e "\e[34m Save them as secret \e[0m"
kubectl create secret generic -n orderer hlf--genesis --from-file=genesis.block
kubectl create secret generic -n org1 hlf--channel --from-file=addenda-channel.tx
cd ..