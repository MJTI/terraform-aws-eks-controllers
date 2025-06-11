resource "aws_efs_file_system" "efs-file-system" {
  creation_token   = "${var.env}-${var.project}-eks"
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"
  encrypted        = true

  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }

  tags = {
    Name       = "${var.project}-efs-file-system"
    Managed_By = "Terraform"
    Project    = var.project
  }
}

resource "aws_efs_mount_target" "mount-all-private-subnets" {
  count = length(var.aws_subnet_private)

  file_system_id  = aws_efs_file_system.efs-file-system.id
  subnet_id       = var.aws_subnet_private[count.index].id
  security_groups = [var.cluster_security_group_id]
}

resource "kubernetes_storage_class_v1" "sc-efs" {
  metadata {
    name = "efs"
  }
  storage_provisioner = "efs.csi.aws.com"
  reclaim_policy      = "Retain"
  parameters = {
    fileSystemId     = aws_efs_file_system.efs-file-system.id
    provisioningMode = "efs-ap"
    directoryPerms   = "700"
  }
  mount_options = ["iam"]

  depends_on = [aws_efs_mount_target.mount-all-private-subnets]
}