resource "aws_eks_addon" "csi-ebs-driver" {
  cluster_name             = var.eks_cluster_name
  addon_name               = "aws-ebs-csi-driver"
  addon_version            = "v1.43.0-eksbuild.1"
  service_account_role_arn = aws_iam_role.eks-ebs.arn
}

resource "aws_iam_role" "eks-ebs" {
  name = "${var.env}-${var.project}-eks-ebs"

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
          Service = "pods.eks.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    Name       = "eks-ebs"
    Managed_By = "Terraform"
    Project    = var.project
  }
}

resource "aws_iam_role_policy_attachment" "amazon-ebs-csi-driver" {
  role       = aws_iam_role.eks-ebs.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

resource "aws_iam_policy" "eks-ebs-encrypt-policy" {
  name   = "amazon-ebs-csi-driver-encrypt"
  policy = file("${path.module}/policies/ebs-encrypt-policy.json")
}

resource "aws_iam_role_policy_attachment" "amazon-ebs-csi-driver-encrypt" {
  role       = aws_iam_role.eks-ebs.name
  policy_arn = aws_iam_policy.eks-ebs-encrypt-policy.arn
}

resource "aws_eks_pod_identity_association" "ebs-csi-identity" {
  cluster_name    = var.eks_cluster_name
  namespace       = "kube-system"
  service_account = "ebs-csi-controller-sa"
  role_arn        = aws_iam_role.eks-ebs.arn
}