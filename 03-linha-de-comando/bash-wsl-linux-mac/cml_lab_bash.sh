#!/usr/bin/env bash
# Cria a topologia de referencia (losango OSPF, 4 roteadores iol-xe) no CML2
# via API REST, usando so bash + curl + jq. Roda em WSL, Linux ou macOS.
#
# Le CML_URL / CML_USERNAME / CML_PASSWORD de .env na raiz do repositorio.
# Nao remove o lab ao final -- confira a convergencia OSPF manualmente no
# console/GUI antes de rodar a limpeza (ver roteiro-linha-de-comando.md).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONFIG_DIR="$REPO_ROOT/01-manual/respostas-configuracao"
ENV_FILE="$REPO_ROOT/.env"

LAB_TITLE="${LAB_TITLE:-teste-cli-bash}"

command -v jq >/dev/null || { echo "Precisa de 'jq' instalado." >&2; exit 1; }
command -v curl >/dev/null || { echo "Precisa de 'curl' instalado." >&2; exit 1; }

# .env pode ter sido salvo com CRLF (editado no Windows) -- tr remove o \r.
CML_URL=$(grep '^CML_URL=' "$ENV_FILE" | cut -d= -f2- | tr -d '\r')
CML_USERNAME=$(grep '^CML_USERNAME=' "$ENV_FILE" | cut -d= -f2- | tr -d '\r')
CML_PASSWORD=$(grep '^CML_PASSWORD=' "$ENV_FILE" | cut -d= -f2- | tr -d '\r')
BASE_URL="${CML_URL%/}/api/v0"   # remove barra final antes de concatenar, senao vira //api/v0 (404)

echo "==> Autenticando em $BASE_URL ..."
TOKEN=$(curl -sk -X POST "$BASE_URL/authenticate" \
  -H "Content-Type: application/json" \
  -d "{\"username\": \"$CML_USERNAME\", \"password\": \"$CML_PASSWORD\"}" \
  | tr -d '"')
[ -n "$TOKEN" ] || { echo "Falha na autenticacao."; exit 1; }
AUTH_HEADER="Authorization: Bearer $TOKEN"
echo "    OK"

echo "==> Checando se ja existe um lab '$LAB_TITLE'..."
EXISTING=$(curl -sk "$BASE_URL/labs?show_all=true&with_data=true" -H "$AUTH_HEADER" \
  | jq -r --arg t "$LAB_TITLE" '.[] | select(.lab_title == $t) | .id')
if [ -n "$EXISTING" ]; then
  echo "    ERRO: ja existe lab '$LAB_TITLE' (id=$EXISTING). Remova antes de rodar de novo." >&2
  exit 1
fi
echo "    OK, nenhum lab de teste pre-existente"

echo "==> Criando lab '$LAB_TITLE'..."
LAB_ID=$(curl -sk -X POST "$BASE_URL/labs" -H "$AUTH_HEADER" -H "Content-Type: application/json" \
  -d "{\"title\": \"$LAB_TITLE\", \"description\": \"Lab de teste da Etapa 3 (linha de comando, trilha bash) -- remover apos confirmacao.\"}" \
  | jq -r '.id')
echo "    lab_id = $LAB_ID"

declare -A NODE_ID
declare -A NODE_X=( [R1]=-440 [R2]=-240 [R3]=-40 [R4]=-240 )
declare -A NODE_Y=( [R1]=-120 [R2]=-320 [R3]=-120 [R4]=80 )

echo "==> Criando os 4 nos (iol-xe) com as configs do gabarito..."
for LABEL in R1 R2 R3 R4; do
  # --arg/--rawfile deixam o jq escapar a config corretamente para JSON (com \n etc.)
  BODY=$(jq -n \
    --arg label "$LABEL" \
    --arg x "${NODE_X[$LABEL]}" \
    --arg y "${NODE_Y[$LABEL]}" \
    --rawfile config "$CONFIG_DIR/$LABEL.txt" \
    '{label: $label, node_definition: "iol-xe", x: ($x | tonumber), y: ($y | tonumber), configuration: $config}')
  NODE_ID[$LABEL]=$(curl -sk -X POST "$BASE_URL/labs/$LAB_ID/nodes?populate_interfaces=true" \
    -H "$AUTH_HEADER" -H "Content-Type: application/json" -d "$BODY" | jq -r '.id')
  echo "    $LABEL -> node_id=${NODE_ID[$LABEL]}"
done

echo "==> Lendo interfaces de cada no para mapear nome -> UUID..."
declare -A IFACE
for LABEL in R1 R2 R3 R4; do
  IFACES_JSON=$(curl -sk "$BASE_URL/labs/$LAB_ID/nodes/${NODE_ID[$LABEL]}/interfaces?data=true&operational=false" -H "$AUTH_HEADER")
  IFACE[${LABEL}_Ethernet0/0]=$(echo "$IFACES_JSON" | jq -r '.[] | select(.label == "Ethernet0/0") | .id')
  IFACE[${LABEL}_Ethernet0/1]=$(echo "$IFACES_JSON" | jq -r '.[] | select(.label == "Ethernet0/1") | .id')
  echo "    $LABEL: Eth0/0=${IFACE[${LABEL}_Ethernet0/0]} Eth0/1=${IFACE[${LABEL}_Ethernet0/1]}"
done

echo "==> Criando os 4 links do losango..."
create_link () {
  local node_a="$1" if_a="$2" node_b="$3" if_b="$4"
  local src="${IFACE[${node_a}_${if_a}]}"
  local dst="${IFACE[${node_b}_${if_b}]}"
  local link_id
  link_id=$(curl -sk -X POST "$BASE_URL/labs/$LAB_ID/links" -H "$AUTH_HEADER" -H "Content-Type: application/json" \
    -d "{\"src_int\": \"$src\", \"dst_int\": \"$dst\"}" | jq -r '.id')
  echo "    $node_a:$if_a <-> $node_b:$if_b -> link_id=$link_id"
}
create_link R1 Ethernet0/0 R2 Ethernet0/0
create_link R2 Ethernet0/1 R3 Ethernet0/1
create_link R3 Ethernet0/0 R4 Ethernet0/0
create_link R4 Ethernet0/1 R1 Ethernet0/1

echo "==> Iniciando o lab..."
curl -sk -X PUT "$BASE_URL/labs/$LAB_ID/start" -H "$AUTH_HEADER" -o /dev/null -w "    HTTP %{http_code}\n"

echo "==> Aguardando todos os nos ficarem STARTED (polling a cada 5s, timeout 300s)..."
DEADLINE=$((SECONDS + 300))
while [ $SECONDS -lt $DEADLINE ]; do
  STATE=$(curl -sk "$BASE_URL/labs/$LAB_ID/lab_element_state" -H "$AUTH_HEADER")
  echo "    $(echo "$STATE" | jq -c '.nodes')"
  NOT_STARTED=$(echo "$STATE" | jq -r '.nodes | to_entries[] | select(.value != "STARTED") | .key' | wc -l)
  if [ "$NOT_STARTED" -eq 0 ]; then
    echo "==> Todos os nos estao STARTED."
    break
  fi
  sleep 5
done

echo
echo "============================================================"
echo "Lab de teste '$LAB_TITLE' criado e iniciado."
echo "lab_id = $LAB_ID"
echo "Confira a convergencia OSPF pelo console/GUI do CML2:"
echo "  show ip ospf neighbor"
echo "  show ip route ospf"
echo "Depois, remova com: cml_lab_bash_cleanup.sh (ou stop/wipe/delete manual)."
echo "============================================================"
