resource "aws_iam_role" "eks-elb" {
  name = "${var.env}-${var.project}-eks-elb"

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
    Name       = "eks-elb"
    Managed_By = "Terraform"
    Project    = var.project
  }
}

resource "aws_iam_policy" "eks-elb-policy" {
  name   = "elb_policy"
  policy = file("${path.module}/policies/elb-policy.json")
}

resource "aws_iam_role_policy_attachment" "elb-policy" {
  role       = aws_iam_role.eks-elb.name
  policy_arn = aws_iam_policy.eks-elb-policy.arn
}

resource "aws_eks_pod_identity_association" "elb-identity" {
  cluster_name    = var.eks_cluster_name
  namespace       = "kube-system"
  service_account = "elb-group"
  role_arn        = aws_iam_role.eks-elb.arn
}