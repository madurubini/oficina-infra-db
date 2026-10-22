# O oficina-app e o oficina-lambda-auth montam a conexão a partir destes
# valores; a senha não sai aqui, ela vem do secret DB_PASSWORD de cada repo.

output "endereco" {
  description = "Host do Postgres (sem a porta)."
  value       = aws_db_instance.principal.address
}

output "porta" {
  description = "Porta do Postgres."
  value       = aws_db_instance.principal.port
}

output "nome_banco" {
  description = "Nome do database."
  value       = aws_db_instance.principal.db_name
}

output "usuario" {
  description = "Usuário administrador do Postgres."
  value       = aws_db_instance.principal.username
}

output "database_url_modelo" {
  description = "Modelo da DATABASE_URL do Prisma; troque SENHA e use schema=homolog ou schema=prod."
  value       = "postgresql://${aws_db_instance.principal.username}:SENHA@${aws_db_instance.principal.address}:${aws_db_instance.principal.port}/${aws_db_instance.principal.db_name}?schema=homolog"
}

output "lambdas_security_group_id" {
  description = "Security group que o oficina-lambda-auth associa às Lambdas para alcançar o banco."
  value       = aws_security_group.lambdas.id
}

output "subnet_ids" {
  description = "Subnets onde as Lambdas devem entrar para alcançar o banco (as mesmas da VPC do repo ①)."
  value       = local.rede.subnet_ids
}
