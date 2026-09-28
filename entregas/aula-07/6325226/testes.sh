#!/usr/bin/env bash
# Testes das rotas mínimas da API de Reserva de Salas (TF Aula 07).
# Uso: suba a API (npm start) e rode ./testes.sh [BASE_URL]

BASE_URL="${1:-http://localhost:3000}"

# Ajuste os nomes dos campos para o que o design do Kiro definiu.
CAMPO_SALA="salaId"
CAMPO_FUNC="funcionario"
CAMPO_INICIO="inicio"
CAMPO_FIM="fim"

FUNC="Weslley"
PASSOU=0
FALHOU=0

# requisicao METODO ROTA [JSON] -> preenche STATUS e BODY
requisicao() {
  local resp
  if [ -n "$3" ]; then
    resp=$(curl -s -w '\n%{http_code}' -X "$1" "$BASE_URL$2" -H 'Content-Type: application/json' -d "$3")
  else
    resp=$(curl -s -w '\n%{http_code}' -X "$1" "$BASE_URL$2")
  fi
  STATUS="${resp##*$'\n'}"
  BODY="${resp%$'\n'*}"
}

# verifica DESCRICAO STATUS_ESPERADOS (ex: "200 201")
verifica() {
  if [[ " $2 " == *" $STATUS "* ]]; then
    echo "  [OK]    $1 -> $STATUS"
    PASSOU=$((PASSOU + 1))
  else
    echo "  [FALHA] $1 -> recebeu $STATUS, esperado $2"
    echo "          corpo: $BODY"
    FALHOU=$((FALHOU + 1))
  fi
}

# contem DESCRICAO TEXTO -> verifica se BODY contém TEXTO
contem() {
  if [[ "$BODY" == *"$2"* ]]; then
    echo "  [OK]    $1"
    PASSOU=$((PASSOU + 1))
  else
    echo "  [FALHA] $1 (não encontrou \"$2\")"
    echo "          corpo: $BODY"
    FALHOU=$((FALHOU + 1))
  fi
}

# extrai o campo id do JSON em BODY (aceita {id}, {sala:{id}}, {reserva:{id}})
extrai_id() {
  node -e 'try { const o = JSON.parse(process.argv[1]); const v = o.id ?? o.sala?.id ?? o.reserva?.id; if (v !== undefined) console.log(v); } catch {}' "$BODY"
}

reserva() {
  echo "{\"$CAMPO_SALA\":$1,\"$CAMPO_FUNC\":\"$2\",\"$CAMPO_INICIO\":\"$3\",\"$CAMPO_FIM\":\"$4\"}"
}

# ids numéricos vão sem aspas no JSON; ids em texto (uuid) vão com aspas
json_id() {
  if [[ "$1" =~ ^[0-9]+$ ]]; then echo "$1"; else echo "\"$1\""; fi
}

if ! curl -s -o /dev/null "$BASE_URL"; then
  echo "API não está respondendo em $BASE_URL. Rode 'npm start' antes."
  exit 1
fi

echo "== Salas =="
requisicao POST /salas '{}'
verifica "POST /salas sem nome é rejeitado" "400"

requisicao POST /salas '{"nome":"Sala Teste"}'
verifica "POST /salas cadastra sala" "200 201"
SALA=$(extrai_id)
if [ -z "$SALA" ]; then
  echo "Não consegui ler o id da sala na resposta: $BODY"
  exit 1
fi
SALA=$(json_id "$SALA")

requisicao GET /salas
verifica "GET /salas lista salas" "200"
contem "GET /salas contém a sala cadastrada" "Sala Teste"

echo "== Reservas =="
requisicao POST /reservas "$(reserva "$SALA" "$FUNC" 2026-10-05T10:00:00 2026-10-05T11:00:00)"
verifica "POST /reservas cria reserva 10h-11h" "200 201"
RESERVA=$(extrai_id)

echo "== Conflito de horário =="
requisicao POST /reservas "$(reserva "$SALA" "Outro" 2026-10-05T10:00:00 2026-10-05T11:00:00)"
verifica "Mesmo horário na mesma sala é bloqueado" "400 409"

requisicao POST /reservas "$(reserva "$SALA" "Outro" 2026-10-05T10:30:00 2026-10-05T11:30:00)"
verifica "Horário sobreposto (10h30-11h30) é bloqueado" "400 409"

requisicao POST /reservas "$(reserva "$SALA" "Outro" 2026-10-05T09:00:00 2026-10-05T12:00:00)"
verifica "Horário que engloba a reserva (9h-12h) é bloqueado" "400 409"

requisicao POST /reservas "$(reserva "$SALA" "Outro" 2026-10-05T11:00:00 2026-10-05T12:00:00)"
verifica "Horário encostado (11h-12h) é permitido" "200 201"

requisicao POST /reservas "$(reserva 999999 "$FUNC" 2026-10-05T10:00:00 2026-10-05T11:00:00)"
verifica "Reserva em sala inexistente é rejeitada" "400 404"

echo "== Reservas por funcionário =="
requisicao GET "/reservas?funcionario=$FUNC"
verifica "GET /reservas?funcionario=$FUNC" "200"
contem "Lista contém a reserva de $FUNC" "$FUNC"
if [[ "$BODY" == *"Outro"* ]]; then
  echo "  [FALHA] Lista de $FUNC trouxe reserva de outro funcionário"
  FALHOU=$((FALHOU + 1))
else
  echo "  [OK]    Lista de $FUNC não traz reservas de outros"
  PASSOU=$((PASSOU + 1))
fi

echo "== Cancelamento =="
requisicao DELETE "/reservas/$RESERVA"
verifica "DELETE /reservas/$RESERVA cancela" "200 204"

requisicao DELETE "/reservas/$RESERVA"
verifica "Cancelar de novo retorna 404" "404"

requisicao POST /reservas "$(reserva "$SALA" "$FUNC" 2026-10-05T10:00:00 2026-10-05T11:00:00)"
verifica "Horário liberado após cancelamento pode ser reservado" "200 201"

echo
echo "Resultado: $PASSOU passaram, $FALHOU falharam"
[ "$FALHOU" -eq 0 ]
