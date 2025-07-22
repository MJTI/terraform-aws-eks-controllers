resource "terraform_data" "sealed-secret-creation" {
  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = "chmod +x ${path.module}/scripts/sealed-secrets-creation.sh; ${path.module}/scripts/sealed-secrets-creation.sh ${var.eks_cluster_name} ${var.region} ${aws_iam_role.sealed-secret.arn}"
  }
  depends_on = [aws_eks_access_entry.sealed-secret-admin]
}

resource "helm_release" "sealed-secret" {
  name       = "sealed-secret"
  namespace  = "kube-system"
  repository = "https://bitnami-labs.github.io/sealed-secrets"
  chart      = "sealed-secrets"
  version    = "2.17.3"

  set = [
    {
      name  = "serviceAccount.name"
      value = "sealed-secret"
    },
    {
      name  = "secretName"
      value = "mprofile-sealed-secret"
    }
  ]

  depends_on = [helm_release.elb, terraform_data.sealed-secret-creation]
}