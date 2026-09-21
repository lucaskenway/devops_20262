# Entrega — Aula 06: Terraform Modules

**Aluno:** Weslley Lucas Souza Alves
**RA:** 6325226
**Data:** 21/09/2026

## Repositório

- URL: https://github.com/lucaskenway/unifaat-devops-portfolio
- Pasta: `aula-06/`
- Commit: [`89fdac9`](https://github.com/lucaskenway/unifaat-devops-portfolio/commit/89fdac9) — `feat(aula-06): biblioteca de módulos Terraform - VPC, SG, EC2, RDS`

## Evidências

- [x] Módulo VPC com for_each para subnets dinâmicas
- [x] Módulo Security Group genérico (regras como lista de objetos)
- [x] Módulo EC2 reutilizável
- [x] Módulo RDS reutilizável
- [x] Composição entre módulos (output de um alimenta input de outro)
- [x] Dois ambientes (dev + staging) usando os mesmos módulos
- [ ] `terraform validate` e `terraform plan` sem erros nos dois ambientes
- [x] README documentando cada módulo (inputs, outputs, exemplo)

> `terraform validate` passou sem erros nos dois ambientes (`dev` e `staging`). O `terraform plan` completo ainda precisa ser executado no AWS Academy Learner Lab (depende de sessão/credenciais ativas) — pendente antes da entrega final.

## Evidência do terraform validate

```
$ cd aula-06/environments/dev && terraform init -backend=false && terraform validate
Terraform has been successfully initialized!
Success! The configuration is valid.

$ cd ../staging && terraform init -backend=false && terraform validate
Terraform has been successfully initialized!
Success! The configuration is valid.
```

## Evidência do terraform plan

[Pendente — rodar `terraform plan` nos dois ambientes com sessão ativa do AWS Academy Learner Lab e colar aqui o output resumido]
