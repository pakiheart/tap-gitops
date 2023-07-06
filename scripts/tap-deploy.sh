#!/bin/bash

# TODO: Add more check if things already exist etc....

# Manual Process
# ./setup-repo.sh CLUSTER-NAME eso
# tanzu-sync/scripts/configure.sh
# create tap-values.yaml
# - provide TLS cert and limit TLSCERTDElgation to the required namespaces
# update sub_path in tanzu-sync/app/values/tanzu-sync.yaml to match tap-gitops directory
# MUST SET THESE ENVIRONMENT VARIABLES
# export AWS_ACCOUNT_ID=
# export AWS_REGION=
# export EKS_CLUSTER_NAME=
# export TAP_PKGR_REPO=
# export INSTALL_REGISTRY_HOSTNAME=
# export INSTALL_REGISTRY_USERNAME=
# export INSTALL_REGISTRY_PASSWORD=


if [ $# -eq 0 ]; then
    >&2 echo -e "No arguments provided\nUsage: " $(basename "$0") "view|build|run|iterate"
    exit 1
fi


read -p "Is this the correct k8s context: $(kubectl config current-context) (y/n): " answer
if [ "$answer" == "y" ] || [ "$answer" == "yes" ]
then
        echo "You accepted the consequences!!!!"
else
        exit 1
fi




./create-policies.sh
./create-irsa-tanzu-sync.sh
./create-irsa-tap-install.sh

aws secretsmanager create-secret \
   --name dev/${EKS_CLUSTER_NAME}/tanzu-sync/sync-git-ssh \
   --secret-string "$(cat <<EOF
{
 "ssh-privatekey": "$(cat ~/.ssh/ra-eks-tap | awk '{printf "%s\\n", $0}')",
 "ssh-knownhosts": "$(ssh-keyscan github.com | awk '{printf "%s\\n", $0}')"
}
EOF
)"

exists=$(aws secretsmanager list-secrets --filter Key="name",Values="dev/${EKS_CLUSTER_NAME}/tanzu-sync/install-registry-dockerconfig" | jq  .SecretList | jq length)
if [ "$exists" -eq "1" ]
then

   aws secretsmanager update-secret \
   --secret-id "$(aws secretsmanager list-secrets --filter Key="name",Values="dev/${EKS_CLUSTER_NAME}/tanzu-sync/install-registry-dockerconfig" | jq  -r '.SecretList[0].ARN')"  \
   --secret-string "$(cat ../secrets/install-registry-dockerconfig.json)"
else 
   aws secretsmanager create-secret \
   --name dev/${EKS_CLUSTER_NAME}/tanzu-sync/install-registry-dockerconfig \
   --secret-string "$(cat ../secrets/install-registry-dockerconfig.json)"
fi

exists=$(aws secretsmanager list-secrets --filter Key="name",Values="dev/${EKS_CLUSTER_NAME}/tap/sensitive-values.yaml" | jq  .SecretList | jq length)
if [ "$exists" -eq "1" ]
then
   aws secretsmanager update-secret \
   --secret-id "$(aws secretsmanager list-secrets --filter Key="name",Values="dev/${EKS_CLUSTER_NAME}/tap/sensitive-values.yaml" | jq  -r '.SecretList[0].ARN')"  \
   --secret-string "$(cat ../secrets/sensitive_values_${EKS_CLUSTER_NAME}.json)"
else 
   aws secretsmanager create-secret \
   --name dev/${EKS_CLUSTER_NAME}/tap/sensitive-values.yaml \
   --secret-string "$(cat ../secrets/sensitive_values_${EKS_CLUSTER_NAME}.json)"
fi


if [ "$1" == "build" ] || [ "$1" == "run" ] || [ "$1" == "iterate" ]; then  
   exists=$(aws secretsmanager list-secrets --filter Key="name",Values="dev/${EKS_CLUSTER_NAME}/tap/tenant-install-secrets" | jq  .SecretList | jq length)
   if [ "$exists" -eq "1" ]
   then
      aws secretsmanager update-secret \
      --secret-id "$(aws secretsmanager list-secrets --filter Key="name",Values="dev/${EKS_CLUSTER_NAME}/tap/tenant-install-secrets" | jq  -r '.SecretList[0].ARN')"  \
      --secret-string "$(cat ../secrets/tenant_install_secrets_${EKS_CLUSTER_NAME}.json)"
   else 
      aws secretsmanager create-secret \
      --name dev/${EKS_CLUSTER_NAME}/tap/tenant-install-secrets \
      --secret-string "$(cat ../secrets/tenant_install_secrets_${EKS_CLUSTER_NAME}.json)"
   fi
fi


kubectl create namespace tap-install

# NOTE: Only needed for custom CA
# kubectl create secret tls wildcard-cert --key="KEY-FILE-NAME.key" --cert="CERTIFICATE-FILE-NAME.crt" -n tanzu-system
# kubectl delete secret kapp-controller-config --namespace tanzu-system
# kubectl create secret generic kapp-controller-config --namespace tanzu-system --from-file caCerts=CUSTOM_CA_CERT
# Kubectl apply -f daemonset.yaml 

cd ../clusters/${EKS_CLUSTER_NAME}
# ../tanzu-sync/scripts/bootstrap.sh
# ../tanzu-sync/scripts/deploy.sh

# kubectl apply -f cluster-config/post-install-app.yaml
