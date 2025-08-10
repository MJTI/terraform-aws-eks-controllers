#!/bin/bash

set -e

CLUSTER_NAME="${1:-}"
REGION="${2:-}"
ASSUME_ROLE="${3:-}"

: "${CLUSTER_NAME:?Missing cluster name}"
: "${REGION:?Missing region}"
: "${ASSUME_ROLE:?Missing assume role}"

log() {
    echo "[INFO] $*" >&2
}

log_error() {
    echo "[ERROR] $*" >&2
}

for cmd in aws kubectl base64 jq; do
    command -v $cmd > /dev/null 2>&1 || {
        log_error "Required command '$cmd' not found. Pleade install it."
        exit 1
    }
done


log "Checking if The Role ${ASSUME_ROLE#*/} Exist..."
aws iam get-role --role-name ${ASSUME_ROLE#*/} > /dev/null 2>&1 || {
    log_error "Role ${ASSUME_ROLE} Not Found!, Or Not Authorized To Assume!"
    exit 1
}
log "Role ${ASSUME_ROLE} Does Exist!"


log "Assuming role: ${ASSUME_ROLE} ..."
CREDS=$(aws sts assume-role \
    --role-arn "$ASSUME_ROLE" \
    --role-session-name "sealedSecretSession" \
    --query 'Credentials' \
    --output json) || {
        log_error "Cannot Assume ${ASSUME_ROLE}."
        exit 1
    }

export AWS_ACCESS_KEY_ID=$(echo "$CREDS" | jq -r .AccessKeyId)
export AWS_SECRET_ACCESS_KEY=$(echo "$CREDS" | jq -r .SecretAccessKey)
export AWS_SESSION_TOKEN=$(echo "$CREDS" | jq -r .SessionToken)

log "Assumed Role Credentials Set"


log "Updating Kubeconfig For Cluster: $CLUSTER_NAME ..."
aws eks update-kubeconfig --name $CLUSTER_NAME --region $REGION

log "Fetching Public Cert And Private Key From AWS Parameter Store..."
CERT=$(aws ssm get-parameters --name mprofile-public-key --with-decryption --query "Parameters[*].Value" --output text | base64 | tr -d '\n')
KEY=$(aws ssm get-parameters --name mprofile-private-key --with-decryption --query "Parameters[*].Value" --output text | base64 | tr -d '\n')

log "Applying TLS Secret To kube-system Namespace..."
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: mprofile-sealed-secret
  namespace: kube-system
  labels:
    sealedsecrets.bitnami.com/sealed-secrets-key: active
type: kubernetes.io/tls
data:
  tls.crt: $CERT
  tls.key: $KEY
EOF

log "Sealed Secret Applied Successfully"