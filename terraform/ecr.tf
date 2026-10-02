data "external" "ecr_repository_lookup" {
  program = [
    var.python_executable,
    "${path.module}/scripts/lookup_ecr_repository.py",
  ]

  query = {
    name   = var.ecr_repository_name
    region = var.aws_region
  }
}

data "aws_ecr_repository" "existing" {
  count = data.external.ecr_repository_lookup.result.exists == "true" ? 1 : 0

  name = var.ecr_repository_name
}

resource "aws_ecr_repository" "app" {
  count = data.external.ecr_repository_lookup.result.exists == "true" ? 0 : 1

  name                 = var.ecr_repository_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = merge(local.common_tags, {
    Name = var.ecr_repository_name
  })

  lifecycle {
    prevent_destroy = true
  }
}