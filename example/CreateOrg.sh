#!/bin/bash

# echo "Enter the NameSpace where you want to deploy this organization"
# read NS
NS=$1
# echo "Enter the Name of organization you want to deploy"
# read ORGNAME
ORGNAME=$2
# echo "Enter the Name of organization MSP"
# read ORGNAMEMSP
ORGNAMEMSP=$3
# echo "Enter CA Name"
# read NAME
# echo "Enter number of peers you want to deploy"
# read NUM

# CA_POD=$(kubectl get pods -n $NS -l "app=ica,release=$NAME" -o jsonpath="{.items[0].metadata.name}")
# CA_INGRESS=$(kubectl get ingress -n $NS -l "app=ica,release=$NAME" -o jsonpath="{.items[0].spec.rules[0].host}")

CA_POD=$(kubectl get pods -n cas -l "app=addenda,release=ca" -o jsonpath="{.items[0].metadata.name}")
CA_INGRESS=$(kubectl get ingress -n cas -l "app=addenda,release=ca" -o jsonpath="{.items[0].spec.rules[0].host}")



for i in $(seq 1 $NUM)
do
 echo -e "\e[34m Fabric Peer$i \e[0m"

 echo -e "\e[34m Install CouchDB chart \e[0m"
 helm install -n "$ORGNAME"-couchdb${i} ../addenda-couchdb/ --namespace $NS -f ./helm_values/cdb-peer.yaml
  sleep 70
 CDB_POD=$(kubectl get pods -n $NS -l "app=couchdb,release="$ORGNAME"-couchdb${i}" -o jsonpath="{.items[*].metadata.name}")
 kubectl logs -n $NS $CDB_POD | grep 'Apache CouchDB has started on'

 echo -e "\e[34m Register peer with CA \e[0m"
 kubectl exec -n cas $CA_POD -- fabric-ca-client register --id.name "$ORGNAME"-peer${i} --id.secret "$ORGNAME"-peer${i}_pw --id.type peer
 FABRIC_CA_CLIENT_HOME=./config fabric-ca-client enroll -d -u https://"$ORGNAME"-peer${i}:"$ORGNAME"-peer${i}_pw@$CA_INGRESS -M "$ORGNAME"-peer${i}_MSP
 echo -e "\e[34m Save the Peer certificate in a secret \e[0m"
 NODE_CERT=$(ls ./config/"$ORGNAME"-peer${i}_MSP/signcerts/*.pem)
 kubectl create secret generic -n $NS hlf--peer${i}-idcert --from-file=cert.pem=${NODE_CERT}
 echo -e "\e[34m Save the Peer private key in another secret \e[0m"
 NODE_KEY=$(ls ./config/"$ORGNAME"-peer${i}_MSP/keystore/*_sk)
 kubectl create secret generic -n $NS hlf--peer${i}-idkey --from-file=key.pem=${NODE_KEY}
 
cat <<EOF >> ./helm_values/$ORGNAME-peer${i}.yaml
image:
  tag: 1.4.1

persistence:
  accessMode: ReadWriteOnce
  size: 1Gi


peer:
  databaseType: CouchDB
  couchdbInstance: $ORGNAME-couchdb${i}
  mspID: $ORGNAMEMSP
#  tls:
#    server:
#      enabled: "true"
#    client:
#      enabled: "true"

secrets:
  peer:
    cert: hlf--peer1-idcert
    key: hlf--peer1-idkey
    caCert: hlf--peer-ca-cert
    # intCaCert: hlf--peer1-caintcert
#  channel: hlf--channel
  adminCert: hlf--peer-admincert
  adminKey: hlf--peer-adminkey

affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 95
        podAffinityTerm:
          topologyKey: "kubernetes.io/hostname"
          labelSelector:
            matchLabels:
              app: addenda
EOF

echo -e "\e[34m Install Fabric Peer Chart \e[0m"
helm install -n "$ORGNAME"-peer${i} ../addenda-peer --namespace $NS -f ./helm_values/"$ORGNAME"-peer${i}.yaml
sleep 60
PEER_POD=$(kubectl get pods --namespace $NS -l "app=addenda,release="$ORGNAME"-peer${i}" -o jsonpath="{.items[0].metadata.name}")
kubectl logs -n $NS $PEER_POD | grep 'Starting peer'

kubectl  exec -n org2 $PEER_POD -- bash -c 'CORE_PEER_MSPCONFIGPATH=$ADMIN_MSP_PATH CORE_PEER_LOCALMSPID=Org2MSP  peer channel fetch 0 /var/hyperledger/addenda-channel.block -c addenda-channel -o addenda1-orderer.orderer.svc.cluster.local:7050'

kubectl  exec -n org2 $PEER_POD -- bash -c 'CORE_PEER_MSPCONFIGPATH=$ADMIN_MSP_PATH CORE_PEER_LOCALMSPID=Org2MSP  peer channel join -b /var/hyperledger/addenda-channel.block'

done

