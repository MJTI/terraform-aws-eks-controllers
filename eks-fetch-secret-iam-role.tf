data "aws_caller_identity" "current" {}

resource "aws_iam_role" "sealed-secret" {
  name = "${var.env}-${var.project}-fetch-sealed-secret"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
        Principal = {
          AWS = [
            "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/awscli",
            "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/terraform-githubaction"
          ]
        }
      }
    ]
  })

  tags = {
    Name       = "sealed-secret"
    Managed_By = "Terraform"
    Project    = var.project
  }
}

resource "aws_iam_policy" "fetch-sealed-secret" {
  name = "${var.env}-${var.project}-fetch-sealed-secrets"

  policy = <<EOT
{
    "Version": "2012-10-17",
    "Statement": [
      {
          "Effect": "Allow",
          "Action": "ssm:GetParameters",
          "Resource": "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/mprofile-*"
      },
      {
        "Effect": "Allow",
        "Action": "eks:ListClusters",
        "Resource": "*"
      },
      {
        "Effect": "Allow",
        "Action": "eks:DescribeCluster",
        "Resource": "arn:aws:eks:${var.region}:${data.aws_caller_identity.current.account_id}:cluster/${var.eks_cluster_name}"
      }
    ]
}
EOT
}

resource "aws_iam_role_policy_attachment" "sealed-secret" {
  role       = aws_iam_role.sealed-secret.name
  policy_arn = aws_iam_policy.fetch-sealed-secret.arn
}

resource "kubernetes_role_v1" "secret-role" {
  metadata {
    name      = "sealed-secrets"
    namespace = "kube-system"
    labels = {
      usage = "creating-secret-for-sealed-secret-controller"
    }
  }

  rule {
    api_groups = [""]
    resources  = ["secrets"]
    verbs      = ["*"]
  }
}

resource "kubernetes_role_binding_v1" "sealed-secret-binding" {
  metadata {
    name      = "sealed-secrets-binding"
    namespace = "kube-system"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = "sealed-secrets"
  }

  subject {
    kind      = "Group"
    name      = "sealed-secret-group"
    api_group = "rbac.authorization.k8s.io"
  }
}

resource "aws_eks_access_entry" "sealed-secret-admin" {
  cluster_name      = var.eks_cluster_name
  principal_arn     = aws_iam_role.sealed-secret.arn
  type              = "STANDARD"
  kubernetes_groups = ["sealed-secret-group"]

  depends_on = [kubernetes_role_binding_v1.sealed-secret-binding]
}