data "tls_certificate" "eks_oidc" {
  url = data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  url = data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer

  client_id_list = ["sts.amazonaws.com"]
  thumbprint_list = [
    data.tls_certificate.eks_oidc.certificates[length(data.tls_certificate.eks_oidc.certificates) - 1].sha1_fingerprint
  ]

  tags = {
    Name        = "${var.cluster_name}-${var.environment}-oidc"
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_iam_policy" "load_balancer_controller" {
  name        = "${var.cluster_name}-${var.environment}-aws-load-balancer-controller"
  description = "Permissions for AWS Load Balancer Controller."
  policy      = file("${path.module}/../iam/aws-load-balancer-controller-policy.json")
}

resource "aws_iam_role" "load_balancer_controller" {
  name = "${var.cluster_name}-${var.environment}-aws-lbc-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.eks.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${replace(data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer, "https://", "")}:aud" = "sts.amazonaws.com"
          "${replace(data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "load_balancer_controller" {
  role       = aws_iam_role.load_balancer_controller.name
  policy_arn = aws_iam_policy.load_balancer_controller.arn
}

resource "kubernetes_service_account_v1" "load_balancer_controller" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.load_balancer_controller.arn
    }
  }

  depends_on = [aws_iam_role_policy_attachment.load_balancer_controller]
}

# Argo CD itself does not need AWS permissions to deploy into the same EKS
# cluster. This IRSA role is provided for optional AWS API/ECR integrations.
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

resource "aws_iam_role" "argocd" {
  name = "${var.cluster_name}-${var.environment}-argocd-irsa-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.eks.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${replace(data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer, "https://", "")}:aud" = "sts.amazonaws.com"
          "${replace(data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:${var.argocd_namespace}:argocd-repo-server"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "argocd_ecr_read" {
  role       = aws_iam_role.argocd.name
  policy_arn = aws_iam_policy.argocd_ecr_read.arn
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
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.argocd.arn
    }
  }

  depends_on = [kubernetes_namespace_v1.argocd]
}
