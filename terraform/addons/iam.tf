# OIDC data and provider commented out due to SCP restrictions
/*
data "tls_certificate" "eks_oidc" {
  url = data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.cluster.identity[0].oidc[0].issuer
}
*/

# --- AWS Load Balancer Controller Setup ---

resource "aws_iam_policy" "load_balancer_controller" {
  name        = "${var.cluster_name}-${var.environment}-aws-load-balancer-controller"
  description = "Permissions for AWS Load Balancer Controller."
  policy      = file("${path.module}/../iam/aws-load-balancer-controller-policy.json")
}

# Attach LBC Policy directly to the Worker Node IAM Role so nodes get LBC permission

resource "aws_iam_role_policy_attachment" "node_lbc_policy" {
  role       = "${var.cluster_name}-${var.environment}-node-role" # Exact name from eks.tf
  policy_arn = aws_iam_policy.load_balancer_controller.arn
}

resource "kubernetes_service_account_v1" "load_balancer_controller" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
  }
}

# --- Argo CD Setup ---

resource "aws_iam_policy" "argocd_ecr_read" {
  name        = "${var.cluster_name}-${var.environment}-argocd-ecr-read"
  description = "Optional ECR read permissions for Argo CD integrations."
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:DescribeRepositories",
        "ecr:DescribeImages"
      ]
      Resource = "*"
    }]
  })
}

resource "kubernetes_namespace_v1" "argocd" {
  metadata {
    name = var.argocd_namespace
  }
}

resource "kubernetes_service_account_v1" "argocd_repo_server" {
  metadata {
    name      = "argocd-repo-server"
    namespace = var.argocd_namespace
  }

  depends_on = [kubernetes_namespace_v1.argocd]
}
