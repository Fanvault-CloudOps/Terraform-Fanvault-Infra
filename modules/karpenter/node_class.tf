# EC2NodeClass defines the AMI family, IAM role, subnet/security-group selectors,
# and EBS configuration for Karpenter-provisioned nodes.
resource "kubernetes_manifest" "ec2_node_class" {
  manifest = {
    apiVersion = "karpenter.k8s.aws/v1"
    kind       = "EC2NodeClass"
    metadata = {
      name = "${var.project_name}-default"
    }
    spec = {
      amiFamily = "AL2023"

      role = var.node_iam_role_name

      # Select subnets tagged as belonging to this cluster (set by EKS during cluster creation)
      subnetSelectorTerms = [
        {
          tags = {
            "kubernetes.io/cluster/${var.cluster_name}" = "owned"
          }
        }
      ]

      # Select security groups tagged as belonging to this cluster
      securityGroupSelectorTerms = [
        {
          tags = {
            "kubernetes.io/cluster/${var.cluster_name}" = "owned"
          }
        }
      ]

      blockDeviceMappings = [
        {
          deviceName = "/dev/xvda"
          ebs = {
            volumeSize          = "20Gi"
            volumeType          = "gp3"
            encrypted           = true
            deleteOnTermination = true
          }
        }
      ]

      tags = {
        Environment = var.environment
        Project     = var.project_name
        ManagedBy   = "karpenter"
      }
    }
  }

  depends_on = [helm_release.karpenter]
}
