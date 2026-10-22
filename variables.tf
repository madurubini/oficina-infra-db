variable "regiao" {
  description = "Região da AWS. O Learner Lab só libera us-east-1 e us-west-2."
  type        = string
  default     = "us-east-1"

  validation {
    condition     = contains(["us-east-1", "us-west-2"], var.regiao)
    error_message = "O Learner Lab só permite us-east-1 ou us-west-2."
  }
}

variable "nome_projeto" {
  description = "Prefixo dos nomes e valor da tag Projeto em todos os recursos."
  type        = string
  default     = "oficina"
}

variable "tf_state_bucket" {
  description = "Bucket S3 onde está o state do oficina-infra-k8s (o mesmo do backend deste repo)."
  type        = string
}

variable "versao_postgres" {
  description = "Versão major do Postgres. A mesma do docker-compose do oficina-app."
  type        = string
  default     = "16"
}

variable "classe_instancia" {
  description = "Classe da instância do RDS. O Learner Lab bloqueia classes grandes."
  type        = string
  default     = "db.t3.micro"
}

variable "armazenamento_gb" {
  description = "Tamanho do disco do banco, em GB."
  type        = number
  default     = 20

  validation {
    condition     = var.armazenamento_gb >= 20 && var.armazenamento_gb <= 50
    error_message = "O RDS exige no mínimo 20 GB; acima de 50 só aumenta o custo."
  }
}

variable "nome_banco" {
  description = "Nome do database criado no Postgres. Homolog e prod são schemas dentro dele."
  type        = string
  default     = "oficina"
}

variable "usuario_banco" {
  description = "Usuário administrador do Postgres."
  type        = string
  default     = "oficina"
}

variable "senha_banco" {
  description = "Senha do usuário administrador. No pipeline vem do secret DB_PASSWORD."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.senha_banco) >= 8 && !can(regex("[/@\" ]", var.senha_banco))
    error_message = "O RDS exige ao menos 8 caracteres e não aceita /, @, aspas duplas nem espaço."
  }
}

variable "dias_backup" {
  description = "Por quantos dias o RDS guarda os backups automáticos (0 desliga)."
  type        = number
  default     = 1
}
