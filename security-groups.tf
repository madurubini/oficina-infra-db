# Quem pode falar com o banco na porta 5432:
# - os pods do EKS, que rodam nos nós com o security group do cluster (output do repo ①);
# - as Lambdas do oficina-lambda-auth, que entram na VPC com o security group criado aqui.
# Nenhum IP de fora da VPC é liberado.

resource "aws_security_group" "banco" {
  name        = "${var.nome_projeto}-db"
  description = "RDS Postgres: aceita conexoes so do cluster EKS e das Lambdas"
  vpc_id      = local.rede.vpc_id

  tags = {
    Name = "${var.nome_projeto}-db"
  }
}

resource "aws_vpc_security_group_ingress_rule" "banco_do_cluster" {
  security_group_id            = aws_security_group.banco.id
  description                  = "Postgres a partir dos nos do EKS"
  referenced_security_group_id = local.rede.cluster_security_group_id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
}

resource "aws_vpc_security_group_ingress_rule" "banco_das_lambdas" {
  security_group_id            = aws_security_group.banco.id
  description                  = "Postgres a partir das Lambdas"
  referenced_security_group_id = aws_security_group.lambdas.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
}

# Fica neste repo (e não no ④) porque é a regra do banco que depende dele.
# O oficina-lambda-auth só associa este id às Lambdas que acessam o RDS.
resource "aws_security_group" "lambdas" {
  name        = "${var.nome_projeto}-lambdas"
  description = "Lambdas do oficina-lambda-auth que acessam o RDS"
  vpc_id      = local.rede.vpc_id

  tags = {
    Name = "${var.nome_projeto}-lambdas"
  }
}

resource "aws_vpc_security_group_egress_rule" "lambdas_para_banco" {
  security_group_id            = aws_security_group.lambdas.id
  description                  = "Saida para o Postgres"
  referenced_security_group_id = aws_security_group.banco.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
}
