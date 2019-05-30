#!/bin/bash

echo -e "\e[34m Generating Config for Org2 and Adding it to channel configuration\e[0m"
./addOrgToChannel.sh
sleep 5

echo -e "\e[34m Deploying Org2 peer \e[0m"
./CreateOrg.sh org2 org2 Org2MSP
echo -e "\e[34m Org2 is now part of network in channel addenda-channel \e[0m"

