#!/bin/bash

    kubectl create ns org2

    CA_POD=$(kubectl get pods -n cas -l "app=addenda,release=ca" -o jsonpath="{.items[0].metadata.name}")

    CA_INGRESS=$(kubectl get ingress -n cas -l "app=addenda,release=ca" -o jsonpath="{.items[0].spec.rules[0].host}")

    echo -e "\e[34m Register peer identiy on CA\e[0m"
    kubectl exec -n cas $CA_POD -- fabric-ca-client register --id.name org2-admin --id.secret PeerAdm2nPW --id.attrs 'admin=true:ecert'


    echo -e "\e[34m Enroll peer organization admin identiy on CA\e[0m"
    FABRIC_CA_CLIENT_HOME=./org2 fabric-ca-client enroll -u https://org2-admin:PeerAdm2nPW@$CA_INGRESS -M ./Org2MSP
    mkdir -p ./org2/Org2MSP/admincerts
    cp ./org2/Org2MSP/signcerts/* ./org2/Org2MSP/admincerts

    echo -e "\e[34m Create a secret to hold the admincert:Peer Organisation\e[0m"
    ORG_CERT=$(ls ./org2/Org2MSP/admincerts/cert.pem)
    kubectl create secret generic -n org2 hlf--peer-admincert --from-file=cert.pem=$ORG_CERT
    echo -e "\e[34m Create a secret to hold the admin key:Peer Organisation\e[0m"
    ORG_KEY=$(ls ./org2/Org2MSP/keystore/*_sk)
    kubectl create secret generic -n org2 hlf--peer-adminkey --from-file=key.pem=$ORG_KEY
    echo -e "\e[34m Create a secret to hold the CA certificate:Peer Organisation\e[0m"
    CA_CERT=$(ls ./org2/Org2MSP/cacerts/*.pem)
    kubectl create secret generic -n org2 hlf--peer-ca-cert --from-file=cacert.pem=$CA_CERT

cd org2

configtxgen -printOrg Org2MSP > org2.json

cd ..

org1_POD=$(kubectl get pods --namespace org1 -l "app=addenda,release=org1cli" -o jsonpath="{.items[0].metadata.name}")

kubectl  exec -n org1 $org1_POD -- bash -c 'mkdir artifacts'

kubectl  cp ./org2/org2.json -n org1 $org1_POD:/artifacts

kubectl  cp script.sh -n org1 $org1_POD:/

kubectl  exec -n org1 $org1_POD -- bash -c './script.sh'