#!/bin/bash

echo -e "\e[34m Hi..!! It will take around 20 min to bootastarp complete network\e[0m"
echo -e "\e[34m We will use CA to generate MSP for Orderer and Org1\e[0m"
echo -e "\e[34m In this network we will deploy 1 CA, 1 Orderer using kafka consensus and 1 Org1 \e[0m"
echo -e "\e[34m Deploying kafka chart itself consumes 10 min, and after each chart there is a waitTime of 70sec \e[0m"
echo -e "\e[34m Please Be PATIENT\e[0m"
echo -e "\e[34m NOTE: All MSP's are transfered as secrets in namespace, In k8's secrets are the best way to share or store certificates\e[0m"


./genConfigViaCA.sh
sleep 5
./orderer.sh 1
sleep 5
./org1.sh 2
sleep 5
./org1-cli.sh
sleep 5
echo -e "\e[34m Congratulations you network has been Bootstrapped successfully\e[0m"

echo -e "\e[34m Now you can add Org2 to the existing network \e[0m"