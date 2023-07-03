#!/bin/bash


# Manual Process
# ./setup-repo.sh CLUSTER-NAME eso
# search and replace 1.5.0 with 1.5.1 in .tanzu dir
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


#cd repo/clusters/${EKS_CLUSTER_NAME}


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

aws secretsmanager create-secret \
   --name dev/${EKS_CLUSTER_NAME}/tanzu-sync/install-registry-dockerconfig \
   --secret-string "$(cat ../secrets/install-registry-dockerconfig.json)"

aws secretsmanager create-secret \
   --name dev/${EKS_CLUSTER_NAME}/tap/sensitive-values.yaml \
   --secret-string "$(cat ../secrets/sensitive_values_${EKS_CLUSTER_NAME}.json)"

if [ "$1" == "build" ] || [ "$1" == "run" ] || [ "$1" == "iterate" ]; then  
   aws secretsmanager create-secret \
      --name dev/${EKS_CLUSTER_NAME}/tap/tenant-install-secrets \
      --secret-string "$(cat ../secrets/tenant_install_secrets_${EKS_CLUSTER_NAME}.json)"
fi



# kubectl create secret tls wildcard-cert --key="KEY-FILE-NAME.key" --cert="CERTIFICATE-FILE-NAME.crt" -n tanzu-system
# kubectl delete secret kapp-controller-config --namespace tanzu-system
# kubectl create secret generic kapp-controller-config --namespace tanzu-system --from-file caCerts=CUSTOM_CA_CERT
# Kubectl apply -f daemonset.yaml 

# ./tanzu-sync/scripts/bootstrap.sh
# ./tanzu-sync/scripts/deploy.sh


