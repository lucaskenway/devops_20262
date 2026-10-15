# Trabalho em Aula — Aula 07: Dividir para Conquistar (Decomposição de Problemas)

**Aluno:** Weslley Lucas Souza Alves
**RA:** 6325226
**Data:** 2026-09-24

> A atividade não tem entrega formal. Este registro documenta a decomposição feita em sala.

## Parte 1 — Sentindo o problema grande

> *"Quero um aplicativo de controle de tarefas para equipes: cada pessoa cria tarefas, atribui a colegas, define prazo e prioridade, marca como concluída, comenta nas tarefas, recebe notificação quando algo é atribuído a ela, e o gestor vê um painel com o andamento de tudo."*

1. **Primeira sensação:** parece simples numa frase, mas não dá para imaginar a solução inteira. Dentro do pedido há pelo menos 6 sistemas diferentes: usuários e equipes, tarefas, atribuição, comentários, notificações e painel. Também ficam perguntas em aberto: quem é "gestor"? Uma pessoa pode estar em mais de uma equipe? A notificação é por e-mail, push ou dentro do app? O "andamento" mede o quê?
2. **Se pedisse tudo de uma vez para uma IA:** ela entregaria um código grande e "plausível" que tenta fazer tudo e não faz nada direito. Escolheria sozinha as respostas para as perguntas acima (provavelmente diferentes do que eu queria), misturaria responsabilidades num arquivo só e deixaria partes como mock ou `TODO`, principalmente notificações e permissões. Sem testes por parte, seria difícil descobrir o que funciona. Para corrigir um ponto, eu teria que reler tudo, e cada correção pedida tenderia a quebrar outra parte.

## Parte 2 — Dividir para conquistar

### Atividade A + B — Partes, já na ordem em que eu faria

| # | Parte (uma frase) | Depende de |
|---|-------------------|-----------|
| 1 | Criar uma tarefa com título | — |
| 2 | Listar as tarefas existentes | 1 |
| 3 | Editar e excluir uma tarefa | 1 |
| 4 | Marcar uma tarefa como concluída (e reabrir) | 1 |
| 5 | Adicionar prazo à tarefa | 1 |
| 6 | Adicionar prioridade (baixa / média / alta) à tarefa | 1 |
| 7 | Filtrar e ordenar a lista por status, prazo e prioridade | 2, 4, 5, 6 |
| 8 | Cadastrar pessoas (usuário com nome e e-mail) | — |
| 9 | Fazer login e identificar quem está usando | 8 |
| 10 | Registrar quem criou cada tarefa | 1, 9 |
| 11 | Criar uma equipe e adicionar membros | 8 |
| 12 | Definir o papel de gestor na equipe | 11 |
| 13 | Atribuir uma tarefa a um colega da mesma equipe | 1, 11 |
| 14 | Ver "minhas tarefas" (as atribuídas a mim) | 2, 13 |
| 15 | Comentar em uma tarefa | 1, 9 |
| 16 | Listar os comentários de uma tarefa em ordem | 15 |
| 17 | Registrar um evento quando uma tarefa é atribuída a alguém | 13 |
| 18 | Mostrar as notificações não lidas da pessoa (dentro do app) | 17 |
| 19 | Marcar uma notificação como lida | 18 |
| 20 | Enviar a notificação também por e-mail | 17 |
| 21 | Painel do gestor: contagem de tarefas por status na equipe | 4, 12 |
| 22 | Painel: tarefas atrasadas e tarefas por pessoa | 5, 13, 21 |
| 23 | Permissões: só membros veem as tarefas da equipe e só o gestor vê o painel | 9, 11, 12 |

**Critério da ordem:**

- **Núcleo primeiro (1–7).** A tarefa é o centro de tudo. Começar por ela entrega algo útil e testável já na primeira parte, mesmo sem login ("lista de tarefas pessoal").
- **Depois, quem usa (8–12).** Atribuir, comentar e notificar exigem saber *quem* é cada pessoa e a qual equipe ela pertence. Isso vem antes de qualquer parte que fale de "colega" ou "gestor".
- **Depois, as funcionalidades que ligam pessoas e tarefas (13–16).**
- **Notificações (17–20).** Só fazem sentido quando a atribuição existe. Separei "registrar o evento" de "mostrar" e de "enviar e-mail": o e-mail é o canal mais difícil e pode vir por último sem bloquear o resto.
- **Painel (21–22) no fim.** Ele só lê dados que as outras partes produzem (status, prazo, atribuição). Se viesse antes, não teria o que mostrar.
- **Permissões (23)** fecham o ciclo. Na prática, cada parte nova já deve respeitar as regras de acesso, mas a regra explícita fica numa tarefa própria, com teste próprio.

### Atividade C — A parte mais difícil

**Escolhida: #17 + #18, as notificações de atribuição.** É a única parte que reage a um evento de outra parte e tem que tratar casos de borda. O que acontece quando a pessoa atribui a tarefa a si mesma? E quando reatribui para a mesma pessoa? E quando a tarefa é atribuída a alguém que saiu da equipe? Depois ainda vem um canal externo (e-mail) que pode falhar.

**Prompt pequeno e específico só dessa parte:**

> "Na API de tarefas já existente (Node/Express, tabela `tasks` com `assignee_id` e tabela `users`), crie a tabela `notifications` (`id`, `user_id`, `task_id`, `type`, `read_at`, `created_at`) e faça com que, **toda vez que o `assignee_id` de uma tarefa mudar para outra pessoa**, seja gravada uma notificação `type = "assigned"` para o novo responsável. Não gere notificação se a pessoa atribuir a tarefa a si mesma nem se o responsável não mudou. Crie `GET /notifications?unread=true` que retorna só as notificações do usuário logado. Não implemente e-mail nem tempo real. Inclua testes Jest para: atribuição nova, reatribuição para a mesma pessoa e autoatribuição."

**Por que esse prompt funciona:**

- Diz **onde** a mudança entra (API e tabelas que já existem), em vez de deixar a IA inventar a arquitetura
- Define a **regra de disparo** e os **casos de borda** de forma explícita
- Delimita o escopo com o que **não** fazer (sem e-mail, sem WebSocket)
- Pede **testes** que provam o comportamento, então dá para validar o resultado sem ler tudo

## Parte 3 — Conexão com o Kiro (laboratório)

| No papel (hoje) | No Kiro (laboratório) |
|-----------------|------------------------|
| A lista das 23 partes | As **Tarefas** (`tasks.md`) do Spec |
| A coluna "Depende de" e a ordem | O **Design** e a sequência das tarefas |
| O prompt da parte mais difícil | Implementar **uma tarefa por vez**, revisando antes de seguir |
| As perguntas em aberto da Parte 1 | Os **Requisitos** (`requirements.md`) com critérios de aceite |

**Conclusão:** a qualidade do que a IA entrega depende muito mais do tamanho e da clareza do pedido do que da ferramenta. Decompor e ordenar antes de pedir é o que transforma "um app de tarefas" em 23 passos que dá para conferir um por um.
