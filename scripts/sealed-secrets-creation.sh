    #!/bin/bash

    set -e

    CLUSTER_NAME="${1:-}"
    REGION="${2:-}"
    ASSUME_ROLE="${3:-}"
    AWS_PROFILE="${4:-default}"

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


    if [[ -n "$ASSUME_ROLE" ]]; then
        log "Assuming role: $ASSUME_ROLE"

        aws iam get-role --role-name "${$ASSUME_ROLE#*/}" || {
            log_error "Role ${ASSUME_ROLE} Not Found!"
            exit 1
        }
        CREDS=$(aws sts assume-role \
            --profile "$AWS_PROFILE" \
            --role-arn "$ASSUME_ROLE" \
            --role-session-name "sealedSecretSession" \
            --query 'Credentials' \
            --output json) || {
                log_error "Cannot Assume ${ASSUME_ROLE}."
                exit 1
            }
        echo $CREDS
        export AWS_ACCESS_KEY_ID=$(echo "$CREDS" | jq -r .AccessKeyId)
        export AWS_SECRET_ACCESS_KEY=$(echo "$CREDS" | jq -r .SecretAccessKey)
        export AWS_SESSION_TOKEN=$(echo "$CREDS" | jq -r .SessionToken)

        log "Assumed role credetials set"
    fi


    log "Updating kubeconfig for cluster: $CLUSTER_NAME"
    aws eks update-kubeconfig --name $CLUSTER_NAME --region $REGION


    log "Fetching public cert and private key from AWS Parameter Store"

    CERT=$(aws ssm get-parameters --name mprofile-public-key --with-decryption --query "Parameters[*].Value" --output text | base64 | tr -d '\n')
    KEY=$(aws ssm get-parameters --name mprofile-private-key --with-decryption --query "Parameters[*].Value" --output text | base64 | tr -d '\n')

    log "Applying TLS secret to kube-system namespace"

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

    log "Sealed secret applied successfully"