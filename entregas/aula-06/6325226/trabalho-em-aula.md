# Trabalho em Aula — Aula 06: Módulos Terraform

**Aluno:** Weslley Lucas Souza Alves
**RA:** 6325226
**Data:** 2026-09-17

## Parte 1 — Identificação de Duplicação

### 1. Blocos de recursos duplicados entre dev e staging

São **7 blocos por ambiente** (14 no total), todos repetidos quase linha a linha:

| # | Recurso | dev | staging |
|---|---------|-----|---------|
| 1 | `aws_vpc` | `dev` | `staging` |
| 2 | `aws_subnet` (pública 1) | `dev_public_1` | `staging_public_1` |
| 3 | `aws_subnet` (pública 2) | `dev_public_2` | `staging_public_2` |
| 4 | `aws_internet_gateway` | `dev` | `staging` |
| 5 | `aws_security_group` (API) | `dev_api` | `staging_api` |
| 6 | `aws_security_group` (RDS) | `dev_rds` | `staging_rds` |
| 7 | `aws_instance` (API) | `dev_api` | `staging_api` |

Dentro de cada ambiente ainda há duplicação menor: as duas subnets só mudam CIDR e AZ, e os blocos `ingress` 80 e 22 do SG da API só mudam a porta.

### 2. O que muda entre dev e staging

Poucos valores:

- **Nome do ambiente** (`dev` / `staging`), que aparece no nome do recurso Terraform, nas tags `Name` e na tag `Environment`
- **CIDR da VPC**: `10.0.0.0/16` / `10.1.0.0/16`
- **CIDR das subnets**: `10.0.1.0/24` e `10.0.2.0/24` / `10.1.1.0/24` e `10.1.2.0/24` (só muda o segundo octeto)

Todo o resto é igual: AZs, AMI, `instance_type`, `key_name`, portas, regras de egress e a tag `Project`. Em produção, os valores que mais tendem a variar por ambiente são justamente `instance_type` e as regras de acesso, e hoje eles estão fixos no código.

### 3. Módulos que eu criaria

1. **`modules/vpc`**: VPC, subnets públicas (e privadas, para o RDS), Internet Gateway e route tables
2. **`modules/security-group`**: SG genérico, com regras de ingress/egress recebidas por variável
3. **`modules/ec2`**: instância da API
4. **`modules/rds`**: banco PostgreSQL, com o DB subnet group em subnets privadas

Mais um módulo de composição, **`modules/environment`** (ou o `main.tf` de cada pasta `envs/dev`, `envs/staging`), que chama os quatro acima e liga os outputs de um nos inputs do outro. Assim um ambiente novo é uma única chamada de módulo.

### 4. Variáveis (inputs) de cada módulo

| Módulo | Inputs |
|--------|--------|
| `vpc` | `project`, `environment`, `vpc_cidr`, `public_subnet_cidrs` (list), `private_subnet_cidrs` (list), `azs` (list), `tags` (map) |
| `security-group` | `name`, `vpc_id`, `ingress_rules` (list de objetos: `from_port`, `to_port`, `protocol`, `cidr_blocks`, `security_groups`), `egress_rules` (com default "libera tudo"), `tags` |
| `ec2` | `name`, `ami`, `instance_type` (default `t2.micro`), `subnet_id`, `security_group_ids` (list), `key_name`, `tags` |
| `rds` | `identifier`, `engine_version`, `instance_class`, `allocated_storage`, `db_name`, `username`, `password` (sensitive), `subnet_ids` (list privadas), `security_group_ids`, `tags` |

`project` e `environment` também alimentam as tags padrão (`Name = "${project}-${environment}-..."`, `Environment`, `Project`), o que acaba com a repetição manual das tags.

### 5. Outputs de cada módulo

| Módulo | Outputs |
|--------|---------|
| `vpc` | `vpc_id`, `public_subnet_ids`, `private_subnet_ids`, `internet_gateway_id`, `vpc_cidr` |
| `security-group` | `sg_id`, `sg_arn` |
| `ec2` | `instance_id`, `public_ip`, `private_ip` |
| `rds` | `endpoint`, `port`, `db_instance_id` |

### 6. Linhas para um ambiente de produção

- **Código atual:** copiar o bloco inteiro de um ambiente, cerca de **86 linhas** (de 173), e trocar nomes, tags e CIDRs à mão em uns 20 lugares. É fácil esquecer um e acabar com `technova-staging-api-sg` dentro da VPC de produção.
- **Com módulos:** uma chamada do módulo de ambiente, cerca de **10–15 linhas**:

```hcl
module "prod" {
  source               = "./modules/environment"
  environment          = "prod"
  vpc_cidr             = "10.2.0.0/16"
  public_subnet_cidrs  = ["10.2.1.0/24", "10.2.2.0/24"]
  private_subnet_cidrs = ["10.2.11.0/24", "10.2.12.0/24"]
  instance_type        = "t3.small"
  ssh_allowed_cidrs    = ["203.0.113.10/32"]
}
```

- **Com `for_each`:** só uma linha nova no mapa de ambientes (`prod = { cidr = "10.2.0.0/16", ... }`).

Com 3 ambientes, o código atual teria cerca de 260 linhas, todas repetidas. Com módulos seriam uns 45 linhas de chamadas, mais os módulos, que são escritos uma vez só.

## Parte 2 — Design de Módulos (Diagrama de Dependências)

```
                         ┌────────────────────────────┐
                         │        modules/vpc         │  ← 1º (não depende de ninguém)
                         │ in:  vpc_cidr, subnets,    │
                         │      azs, environment      │
                         │ out: vpc_id                │
                         │      public_subnet_ids     │
                         │      private_subnet_ids    │
                         └──┬──────────┬───────────┬──┘
                    vpc_id  │          │ vpc_id    │ public / private
                            ▼          ▼           │ subnet_ids
              ┌──────────────────┐  ┌──────────────────┐
              │  SG (API)        │  │  SG (RDS)        │  ← 2º
              │  80 + 22 (restr.)│  │  5432 só do      │
              │  out: sg_id ─────┼─▶│  SG da API       │
              └────────┬─────────┘  │  out: sg_id      │
                       │ sg_id      └────────┬─────────┘
                       │                     │ sg_id
     public_subnet_ids │   private_subnet_ids│
                       ▼                     ▼
              ┌──────────────────┐  ┌──────────────────┐
              │   modules/ec2    │  │   modules/rds    │  ← 3º (podem ser criados em paralelo)
              │ out: public_ip   │  │ out: endpoint    │
              └──────────────────┘  └──────────────────┘
```

**Ordem de criação:** VPC → SG da API → SG do RDS (usa o `sg_id` da API como origem da regra 5432) → EC2 e RDS em paralelo. O Terraform deduz essa ordem sozinho pelas referências entre outputs e inputs, sem precisar de `depends_on`.

- **Módulo criado primeiro e por quê:** a **VPC**. Todos os outros recursos vivem dentro dela e precisam do `vpc_id` ou dos `subnet_ids`, que só existem depois que ela é criada.
- **Output da VPC que os Security Groups consomem:** `vpc_id`. Um SG pertence a uma VPC.
- **Quantos módulos o EC2 depende:** **2 diretamente**, a VPC (`public_subnet_ids`) e o SG da API (`sg_id`). A VPC também entra de forma indireta, pelo SG.
- **O que acontece com os outros módulos ao destruir a VPC:** o Terraform destrói tudo o que depende dela antes, em ordem reversa: EC2 e RDS, depois os SGs, depois subnets e IGW, e por último a VPC. Com `terraform destroy -target=module.vpc` ele avisa que vai levar os dependentes junto. Se alguém tentar apagar a VPC fora do Terraform, a AWS recusa (`DependencyViolation`) enquanto houver recursos dentro dela. Para o RDS isso significa **perda de dados** se não houver snapshot final (`skip_final_snapshot = false`) ou `deletion_protection`.
- **Vantagem de um módulo genérico de Security Group:** um único código testado serve para API, RDS, bastion, load balancer e o que vier depois. Só as regras mudam, e elas passam a ser **dados** (variáveis), não código copiado. Corrigir um padrão (ex.: tags, descrição obrigatória, egress padrão) vale para todos de uma vez. Também fica fácil revisar as regras de cada ambiente no mesmo lugar, o que facilita, por exemplo, fechar o SSH `0.0.0.0/0` que hoje está aberto nos dois ambientes.

### Discussão em grupo

- **`for_each` nos ambientes:** sim, dá para usar `for_each` num único bloco de módulo com um mapa `{ dev = {...}, staging = {...} }`. Funciona bem quando os ambientes compartilham o mesmo state e o mesmo ciclo de vida. Para produção eu prefiro **pastas/states separados** (`envs/prod`): um `apply` em dev não consegue nem tocar em prod, e cada ambiente pode fixar uma versão diferente do módulo.
- **Maior dificuldade na refatoração:** não recriar a infraestrutura ao mover o código. Mudar `aws_vpc.dev` para `module.dev.aws_vpc.this` muda o endereço no state, e o Terraform entende como "destruir e criar". É preciso usar blocos `moved {}` (ou `terraform state mv`) e conferir que o `plan` mostra **0 to destroy** antes de qualquer `apply`.
- **Problemas encontrados no código original**, além da duplicação: SSH 22 aberto para `0.0.0.0/0`, AMI fixa no código (melhor um `data "aws_ami"`) e nenhuma subnet privada, embora exista um SG de RDS. O RDS precisaria de subnets privadas.
