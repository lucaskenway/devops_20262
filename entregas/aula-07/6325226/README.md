# API de Reserva de Salas — Aula 07

Weslley Lucas Souza Alves — RA 6325226

## Como rodar

```bash
npm install
npm start
```

## Rotas

| Método | Rota | Descrição |
|--------|------|-----------|
| POST | `/salas` | Cadastra uma sala (nome obrigatório) |
| GET | `/salas` | Lista as salas cadastradas |
| POST | `/reservas` | Cria uma reserva (sala, funcionário, horário) — bloqueia conflito de horário |
| DELETE | `/reservas/:id` | Cancela uma reserva |
| GET | `/reservas?funcionario=NOME` | Lista as reservas de um funcionário |

## Exemplos de teste (curl)

<!-- Preencher após a implementação -->
