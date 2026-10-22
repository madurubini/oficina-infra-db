# oficina-infra-db

Terraform do banco gerenciado da Oficina: RDS Postgres dentro da VPC criada pelo `oficina-infra-k8s`, com acesso liberado só para o cluster e para as Lambdas.

## Tecnologias

- **Terraform** ≥ 1.10 com provider `hashicorp/aws` 6.x
- **AWS**: RDS for PostgreSQL 16, security groups da VPC, S3 (state remoto com lock nativo)
- **GitHub Actions** para plan/apply/destroy
- Ambiente: **AWS Academy Learner Lab**

## Arquitetura deste repositório

```
 VPC oficina-vpc (criada pelo oficina-infra-k8s, lida via remote state)
 ┌──────────────────────────────────────────────────────────────────┐
 │                                                                  │
 │   nós do EKS (pods do oficina-app)      Lambdas do lambda-auth   │
 │   SG do cluster (output do ①)           SG oficina-lambdas       │
 │              │                                   │               │
 │              └──────────── tcp 5432 ─────────────┘               │
 │                               ▼                                  │
 │                ┌──────────────────────────────┐                  │
 │                │ SG oficina-db                │                  │
 │                │ RDS oficina-db               │                  │
 │                │ Postgres 16 · db.t3.micro    │                  │
 │                │ sem IP público · 1 zona      │                  │
 │                │ database "oficina"           │                  │
 │                │   schema homolog · prod      │                  │
 │                └──────────────────────────────┘                  │
 │      db subnet group = as subnets do ① (2 zonas)                 │
 └──────────────────────────────────────────────────────────────────┘
   S3 <bucket>/infra-k8s/terraform.tfstate ──► lido aqui (VPC, subnets, SG do cluster)
   S3 <bucket>/infra-db/terraform.tfstate  ◄── state deste repo
```

Decisões:
- **RDS em vez do StatefulSet da Fase 2**: a AWS cuida de backup, atualização de versão e disco, e o
  banco sobrevive à recriação do cluster.
- **Um banco para os dois ambientes**: `homolog` e `prod` são *schemas* do mesmo database (a
  `DATABASE_URL` do Prisma termina em `?schema=homolog` ou `?schema=prod`). Separa os dados sem
  dobrar o custo.
- **Sem IP público**: o banco fica nas subnets do ① (que são públicas, porque não há NAT), mas sem
  endereço público. Só é alcançável de dentro da VPC.
- **Acesso por security group, não por IP**: a porta 5432 só aceita quem está no SG do cluster EKS
  ou no SG `oficina-lambdas`. O SG das Lambdas nasce aqui porque é a regra do banco que depende
  dele; o `oficina-lambda-auth` só o associa às funções.
- **Sem Multi-AZ, sem snapshot final e sem proteção contra deleção**: o lab é derrubado ao fim de
  cada sessão; o destroy precisa apagar tudo sem travar.
- **Senha fora do código**: vem da variável `senha_banco`, que no pipeline é o secret `DB_PASSWORD`.

## Saídas (consumidas pelos outros repos)

| Output | Quem usa |
|---|---|
| `endereco`, `porta`, `nome_banco`, `usuario`, `database_url_modelo` | `oficina-app` (secret `DATABASE_URL`) e `oficina-lambda-auth` |
| `lambdas_security_group_id`, `subnet_ids` | `oficina-lambda-auth` (Lambdas dentro da VPC) |

A senha não é output: cada repo que conecta no banco recebe o mesmo `DB_PASSWORD` como secret.

## Pipeline (CI/CD)

| Evento | O que roda |
|---|---|
| Pull request para `homolog` ou `main` | `fmt -check`, `validate`, `plan` (check obrigatório `terraform-plan`) |
| Push em `homolog` | `apply` — deploy de homologação |
| Push em `main` | `apply` — deploy de produção |
| Manual (**Actions → Terraform → Run workflow**, digitar `destruir`) | `destroy` |

O `plan` lê o state do `oficina-infra-k8s`: **o cluster precisa estar de pé** antes. Se o state do
① estiver vazio, o plan falha com a mensagem "suba o repo ① antes deste".

Fluxo de trabalho: `feat/*` → PR → `homolog` (deploy homolog) → PR → `main` (deploy prod).

### Configuração do repositório (uma vez)

- **Secrets** (Settings → Secrets and variables → Actions → *Secrets*): `AWS_ACCESS_KEY_ID`,
  `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN` (mudam a cada sessão do Learner Lab) e
  `DB_PASSWORD` (mínimo 8 caracteres, sem `/`, `@`, `"` nem espaço).
- **Variável** (mesma tela → *Variables*): `TF_STATE_BUCKET` = nome do bucket S3 do state (o mesmo
  do `oficina-infra-k8s`).
- **Ruleset** da `main`: PR obrigatório, bloqueio de force push e deleção, e status check
  `terraform-plan` obrigatório.

## Como rodar localmente

```bash
# 1. Credenciais do Learner Lab em ~/.aws/credentials e o oficina-infra-k8s já aplicado
aws sts get-caller-identity

# 2. Subir
cp backend.hcl.example backend.hcl   # e coloque o nome do bucket
terraform init -backend-config=backend.hcl
export TF_VAR_tf_state_bucket=oficina-tfstate-SEU-RM
export TF_VAR_senha_banco='uma-senha-forte'
terraform apply

# 3. Conferir: um pod de teste no EKS conecta no banco
aws eks update-kubeconfig --region us-east-1 --name oficina-eks
kubectl run psql-teste --rm -it --restart=Never --image=postgres:16-alpine -- \
  psql "postgresql://oficina:$TF_VAR_senha_banco@$(terraform output -raw endereco):5432/oficina" \
  -c 'select version();'

# 4. Derrubar ao terminar (depois de derrubar ④ e ③, antes do ①)
terraform destroy
```

O RDS leva ~5–10 min para subir e ~5 min para cair.

## Custo (referência us-east-1)

| Recurso | Aproximado |
|---|---|
| db.t3.micro Single-AZ | US$ 0,018/h |
| 20 GB gp3 | ~US$ 0,003/h |
| Backup (até o tamanho do disco) | grátis |

≈ **US$ 0,02/h** com este repo ligado. Sempre rode o `destroy` ao terminar a sessão.

## Onde este repositório se encaixa

A Fase 3 é dividida em 4 repositórios, que se conversam por nomes na AWS, pelo state do Terraform
no S3 e por secrets do GitHub (nenhum importa código de outro):

| # | Repositório | O que cria |
|---|---|---|
| ① | [`oficina-infra-k8s`](https://github.com/madurubini/oficina-infra-k8s) | VPC, subnets, cluster EKS, nós e ECR |
| ② | [`oficina-infra-db`](https://github.com/madurubini/oficina-infra-db) | RDS Postgres dentro da VPC do ① |
| ③ | [`oficina-app`](https://github.com/madurubini/oficina-app) | API NestJS no EKS + Load Balancer |
| ④ | [`oficina-lambda-auth`](https://github.com/madurubini/oficina-lambda-auth) | API Gateway, Lambda `auth-cpf` e Lambda Authorizer |

**Ordem para subir:** ① → ② → ③ → ④. **Ordem para derrubar:** ④ → ③ → ② → ①.

Branches: **`main` = produção** (só recebe PR), **`homolog` = homologação**.
