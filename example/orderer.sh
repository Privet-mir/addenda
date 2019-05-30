

echo -e "\e[34m Install Kafka chart \e[0m"
helm install incubator/kafka -n kafka-hlf --namespace orderer -f ./helm_values/kafka-hlf.yaml
echo -e "\e[34m Please be patient Kafka chart is getting install it migth take upto 10 min\e[0m"
sleep 500

CA_POD=$(kubectl get pods -n cas -l "app=addenda,release=ca" -o jsonpath="{.items[0].metadata.name}")

CA_INGRESS=$(kubectl get ingress -n cas -l "app=addenda,release=ca" -o jsonpath="{.items[0].spec.rules[0].host}")


NUM=$1

for i in $(seq 1 $NUM)
do 
echo -e "\e[34m Deploy Orderer$i \e[0m"

kubectl exec -n cas $CA_POD -- fabric-ca-client register --id.name ord${i} --id.secret ord${i}_pw --id.type orderer

FABRIC_CA_CLIENT_HOME=./config fabric-ca-client enroll -d -u https://ord${i}:ord${i}_pw@$CA_INGRESS -M ord${i}_MSP
echo -e "\e[34m Save the Orderer certificate in a secret\e[0m"
NODE_CERT=$(ls ./config/ord${i}_MSP/signcerts/*.pem)
kubectl create secret generic -n orderer hlf--ord${i}-idcert --from-file=cert.pem=${NODE_CERT}
echo -e "\e[34m Save the Orderer private key in another secret \e[0m"
NODE_KEY=$(ls ./config/ord${i}_MSP/keystore/*_sk)
kubectl create secret generic -n orderer hlf--ord${i}-idkey --from-file=key.pem=${NODE_KEY}



echo -e "\e[34m Deploy Orderer$i helm chart \e[0m"
helm install -n addenda${i} ../addenda-ord --namespace orderer -f ./helm_values/ord${i}.yaml
sleep 30
ORD_POD=$(kubectl get pods --namespace orderer -l "app=orderer,release=addenda$i" -o jsonpath="{.items[0].metadata.name}")
kubectl logs -n orderer $ORD_POD | grep 'Starting orderer'
done