locals {
  tags_comuns = {
    Projeto       = var.nome_projeto
    Repo          = "oficina-infra-db"
    GerenciadoPor = "terraform"
  }

  # O que o oficina-infra-k8s criou (VPC, subnets e o security group do cluster).
  rede = data.terraform_remote_state.infra_k8s.outputs
}

# Lê o state do repo ① no S3. É assim que este repo descobre a VPC sem
# importar código de lá: o ① publica outputs, o ② só os consome.
data "terraform_remote_state" "infra_k8s" {
  backend = "s3"

  config = {
    bucket = var.tf_state_bucket
    key    = "infra-k8s/terraform.tfstate"
    region = var.regiao
  }

  # Depois de um destroy o state do ① existe, mas sem outputs.
  lifecycle {
    postcondition {
      condition     = can(self.outputs.vpc_id)
      error_message = "O state do oficina-infra-k8s está vazio: suba o repo ① (VPC + EKS) antes deste."
    }
  }
}
