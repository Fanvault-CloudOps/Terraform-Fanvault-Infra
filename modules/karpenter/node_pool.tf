# NodePool defines scheduling constraints, instance requirements, and disruption policy.
# spot is preferred (ordered first); on-demand is the fallback.
resource "kubernetes_manifest" "node_pool" {
  manifest = {
    apiVersion = "karpenter.sh/v1"
    kind       = "NodePool"
    metadata = {
      name = "${var.project_name}-default"
    }
    spec = {
      template = {
        metadata = {
          labels = {
            "karpenter.sh/nodepool" = "${var.project_name}-default"
            Environment             = var.environment
          }
        }
        spec = {
          nodeClassRef = {
            group = "karpenter.k8s.aws"
            kind  = "EC2NodeClass"
            name  = "${var.project_name}-default"
          }
          requirements = [
            {
              key      = "kubernetes.io/arch"
              operator = "In"
              values   = ["amd64"]
            },
            {
              key      = "karpenter.sh/capacity-type"
              operator = "In"
              values   = ["spot", "on-demand"]
            },
            {
              key      = "node.kubernetes.io/instance-type"
              operator = "In"
              values   = var.instance_types
            },
            {
              key      = "topology.kubernetes.io/zone"
              operator = "In"
              values   = ["us-east-1a", "us-east-1b"]
            }
          ]
        }
      }

      # Hard caps to prevent runaway costs
      limits = {
        cpu    = var.max_nodes_cpu
        memory = var.max_nodes_memory
      }

      # Consolidation: remove underutilized nodes after 30 seconds
      disruption = {
        consolidationPolicy = "WhenEmptyOrUnderutilized"
        consolidateAfter    = "30s"
      }
    }
  }

  depends_on = [kubernetes_manifest.ec2_node_class]
}
