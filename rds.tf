# O RDS fica nas subnets do repo ① (só existem públicas, porque não há NAT),
# mas sem IP público: ele só é alcançável de dentro da VPC, e o security group
# ainda restringe a quem pode falar na porta 5432.

resource "aws_db_subnet_group" "principal" {
  name       = "${var.nome_projeto}-db"
  subnet_ids = local.rede.subnet_ids

  tags = {
    Name = "${var.nome_projeto}-db"
  }
}

resource "aws_db_instance" "principal" {
  identifier     = "${var.nome_projeto}-db"
  engine         = "postgres"
  engine_version = var.versao_postgres
  instance_class = var.classe_instancia

  allocated_storage = var.armazenamento_gb
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = var.nome_banco
  username = var.usuario_banco
  password = var.senha_banco
  port     = 5432

  db_subnet_group_name   = aws_db_subnet_group.principal.name
  vpc_security_group_ids = [aws_security_group.banco.id]
  publicly_accessible    = false

  # Uma zona só: Multi-AZ dobraria o custo e o lab é derrubado ao fim de cada sessão.
  multi_az = false

  backup_retention_period = var.dias_backup
  apply_immediately       = true

  # Rotina subir → testar → derrubar: o destroy precisa apagar tudo sem
  # parar para tirar snapshot final nem esbarrar em proteção contra deleção.
  skip_final_snapshot = true
  deletion_protection = false

  # Monitoramento avançado e Performance Insights exigem role própria do IAM,
  # que o Learner Lab não deixa criar. A observabilidade fica com o New Relic.
  monitoring_interval          = 0
  performance_insights_enabled = false

  tags = {
    Name = "${var.nome_projeto}-db"
  }
}
