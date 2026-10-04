resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_chart_version
  namespace        = var.argocd_namespace
  create_namespace = true

  wait            = true
  timeout         = 900
  atomic          = true
  cleanup_on_fail = true

  values = [yamlencode({
    configs = {
      params = {
        "server.insecure" = "true"
      }
    }
    server = {
      service = {
        type = "ClusterIP"
      }
    }
    repoServer = {
      serviceAccount = {
        create = false
        name   = "argocd-repo-server"
      }
    }
  })]

  depends_on = [kubernetes_service_account_v1.argocd_repo_server]
}

resource "helm_release" "load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = var.load_balancer_controller_chart_version
  namespace  = "kube-system"

  wait            = true
  timeout         = 900
  atomic          = true
  cleanup_on_fail = true

  set {
    name  = "clusterName"
    value = var.cluster_name
  }

  set {
    name  = "region"
    value = var.aws_region
  }

  set {
    name  = "vpcId"
    value = var.vpc_id
  }

  set {
    name  = "serviceAccount.create"
    value = "false"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  depends_on = [kubernetes_service_account_v1.load_balancer_controller]
}


resource "helm_release" "metrics_server" {
  name             = "metrics-server"
  repository       = "https://kubernetes-sigs.github.io/metrics-server/"
  chart            = "metrics-server"
  version          = "3.13.1"
  namespace        = "kube-system"
  create_namespace = false

  wait            = true
  timeout         = 600
  atomic          = true

  depends_on = [helm_release.load_balancer_controller]
}
