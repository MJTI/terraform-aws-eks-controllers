variable "region" {
  description = "AWS region name that will be using"
  type        = string
}

variable "env" {
  description = "environment (prod - dev - stage)"
  type        = string
}

variable "project" {
  description = "The name of the project"
  type        = string
}

variable "eks_cluster_name" {
  description = "Cluster Name"
}

variable "vpc_id" {
  description = "VPC ID"
}

variable "aws_subnet_private_ids" {
  description = "Private Subnets"
  type = list(string)
}

variable "cluster_security_group_id" {
  description = "Cluster Security Group ID"
}

variable "eks_host" {
  description = "EKS Cluster Host"
  type = string
}

variable "cluster_ca_certificate" {
  description = "Cluster CA Certificate"
  type = string
}