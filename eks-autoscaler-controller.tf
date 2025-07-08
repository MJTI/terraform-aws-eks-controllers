resource "helm_release" "this" {
  name       = "autcoscaler"
  namespace  = "kube-system"
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  version    = "9.46.6" 

  set = [
    {
      name  = "rbac.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
      value = aws_iam_role.eks-autoscaler.arn
    },
    {
      name  = "cloudProvider"
      value = "aws"
    },
    {
      name  = "autoDiscovery.clusterName"
      value = var.eks_cluster_name
    },
    {
      name  = "awsRegion"
      value = var.region
    },
    {
      name  = "rbac.serviceAccount.name"
      value = "auto-scaling-group"
    }
  ]

  depends_on = [helm_release.metrics]
}

resource "helm_release" "metrics" {
  name       = "metrics-api"
  namespace  = "kube-system"
  repository = "https://kubernetes-sigs.github.io/metrics-server"
  chart      = "metrics-server"

}