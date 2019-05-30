# Addenda

In this task i've deployed 1 orderer using kafka consensus, 1 Org with 2 peers and a CA. Org1 also contains a CLI which is configured with similar environment of peer1

## Pre-requisites
* GKE (Google Kubernetes Engine) with 4 nodes
* Ubuntu 16.04
* Hyperledger fabric binaries
* DNS

## Details 

  All the MSP(crypto material) are generated using fabric CA and all MSP are stored/transfered into respective namespaces using secrets  this is the secure method in k8s to store or manage any kind of credentials or information
  All secrets are then mounted as data volumes or as environment variable inside pod


## Configure K8's
I am using Nginx Ingress service for CA which exposes CA over https outside cluster using DNS, Certmanager is used to auto generate the tls certificates required, I am using Letsencrypt which issues free ssl/tls certificates and Letsencrypt root cert has been passed in fabric-ca-client-config.yaml file in the section

```    
    tls:
       certfiles:
         - ./Lets_Encrypt_Authority_X3.pem```


To configure all of the above services simply run 

```
   $: cd addenda/example
   $: ./configk8s.sh
```

Once all services have been deployed on k8s run following command.

```
$: kubectl --namespace ingress-controller get services -o wide -w nginx-ingress-controller
```

Copy the external IP displayed on termial

Now goto your DNS provider page and open DNS manage section add following info

```
    record type : A
    Name: *.add
    value: paste here nginx ingress external ip that you copied
``` 
SAVE

After this open file helm_values/ca.yaml make following changes
```
ingress:
  enabled: true
  annotations:
    kubernetes.io/ingress.class: nginx
    certmanager.k8s.io/cluster-issuer: "letsencrypt-production"
  path: /
  hosts:
    # TODO: Change this to your Domain Name
    - ca.add.yourdns.com
  tls:
    - secretName: ca--tls
      hosts:
        # TODO: Change this to your Domain Name
        - ca.add.yourdns.com
```

## Bootstrap Network
Bootstraping network consumes minimum of 20 min. deploying kafka charts will itself consume 10 min and after each chart theres a waitTime of 70seconds

from terminal run
```
$: ./main.sh 
```

This will take minimum of 20 min.

Once script has completed executing Channel will be created with name addenda-channel and both peers will have joined the channel

Now we can add Org2 to the network for this RUN
```
$: ./addOrgToChannel.sh
```

This will generate MSP for Org2 and will add Org2 to addenda-channel

**KNOW ISSUE** Once the script has completed running it does not exit you will still see prompt after log  **sucessfully submitted channel update** so please use CTRL+C to exit.

Now lets Create Org2 Pod and make org2 peer1 join addenda-channel
```
$:./CreateOrg.sh
```

Now Org2 has sucessfully joined the network
