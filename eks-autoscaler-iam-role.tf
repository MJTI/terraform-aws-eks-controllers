resource "aws_eks_addon" "pod-identity" {
  cluster_name  = var.eks_cluster_name
  addon_name    = "eks-pod-identity-agent"
  addon_version = "v1.3.7-eksbuild.2"
}

resource "aws_iam_role" "eks-autoscaler" {
  name = "${var.env}-${var.project}-eks-autoscaler"

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
    Name       = "eks-autoscaler"
    Managed_By = "Terraform"
    Project    = var.project
  }
}

resource "aws_iam_policy" "eks-autoscaler-policy" {
  name = "FullClusterAutoscalerFeaturesPolicy"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances",
          "autoscaling:DescribeLaunchConfigurations",
          "autoscaling:DescribeScalingActivities",
          "ec2:DescribeImages",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeLaunchTemplateVersions",
          "ec2:GetInstanceTypesFromInstanceRequirements",
          "eks:DescribeNodegroup"
        ],
        "Resource" : ["*"]
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "autoscaling:SetDesiredCapacity",
          "autoscaling:TerminateInstanceInAutoScalingGroup"
        ],
        "Resource" : ["*"]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "full-cluster-autoscaler-features-policy" {
  role       = aws_iam_role.eks-autoscaler.name
  policy_arn = aws_iam_policy.eks-autoscaler-policy.arn
}

resource "aws_eks_pod_identity_association" "autoscaler-identity" {
  cluster_name    = var.eks_cluster_name
  namespace       = "kube-system"
  service_account = "auto-scaling-group"
  role_arn        = aws_iam_role.eks-autoscaler.arn
}