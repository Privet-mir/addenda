#!/bin/bash

kubectl create -f ./helm-rbac.yaml

helm init --service-account tiller

helm repo add incubator https://kubernetes-charts-incubator.storage.googleapis.com/

helm repo update

kubectl apply   -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.6/deploy/manifests/00-crds.yaml

helm install stable/nginx-ingress -n nginx-ingress --namespace ingress-controller

helm install stable/cert-manager -n cert-manager --namespace cert-manager

kubectl create -f ./extra/certManagerCI_staging.yaml

kubectl create -f ./extra/certManagerCI_production.yaml