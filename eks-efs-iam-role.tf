resource "aws_eks_addon" "csi-efs-driver" {
  cluster_name             = var.eks_cluster_name
  addon_name               = "aws-efs-csi-driver"
  addon_version            = "v2.1.8-eksbuild.1"
  service_account_role_arn = aws_iam_role.eks-efs.arn
}

resource "aws_iam_role" "eks-efs" {
  name = "${var.env}-${var.project}-eks-efs"

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
    Name       = "eks-efs"
    Managed_By = "Terraform"
    Project    = var.project
  }
}

resource "aws_iam_role_policy_attachment" "amazon-efs-csi-driver" {
  role       = aws_iam_role.eks-efs.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEFSCSIDriverPolicy"
}

resource "aws_eks_pod_identity_association" "efs-csi-identity" {
  cluster_name    = var.eks_cluster_name
  namespace       = "kube-system"
  service_account = "efs-csi-controller-sa"
  role_arn        = aws_iam_role.eks-efs.arn
}