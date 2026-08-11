#!/usr/bin/env bash
# Remove o lab de teste criado por cml_lab_bash.sh (stop -> wipe -> delete).
# O CML2 nao deixa remover um lab que nao passou por wipe -- DELETE direto
# num lab so STOPPED da erro 400.
set -euo pipefail

# 1. Configuração e Dependências: Carrega as variáveis de ambiente e define caminhos
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ENV_FILE="$REPO_ROOT/.env"

LAB_TITLE="${LAB_TITLE:-teste-cli-bash}"

# Valida se o binário jq está instalado
command -v jq >/dev/null || { echo "Precisa de 'jq' instalado." >&2; exit 1; }

CML_URL=$(grep '^CML_URL=' "$ENV_FILE" | cut -d= -f2- | tr -d '\r')
CML_USERNAME=$(grep '^CML_USERNAME=' "$ENV_FILE" | cut -d= -f2- | tr -d '\r')
CML_PASSWORD=$(grep '^CML_PASSWORD=' "$ENV_FILE" | cut -d= -f2- | tr -d '\r')
BASE_URL="${CML_URL%/}/api/v0"

# 2. Autenticação: Obtém o token JWT da API do CML2
TOKEN=$(curl -sk -X POST "$BASE_URL/authenticate" \
  -H "Content-Type: application/json" \
  -d "{\"username\": \"$CML_USERNAME\", \"password\": \"$CML_PASSWORD\"}" \
  | tr -d '"')
AUTH_HEADER="Authorization: Bearer $TOKEN"

# 3. Localização do Lab: Encontra o ID do laboratório correspondente ao título procurado
LAB_ID=$(curl -sk "$BASE_URL/labs?show_all=true&with_data=true" -H "$AUTH_HEADER" \
  | jq -r --arg t "$LAB_TITLE" '.[] | select(.lab_title == $t) | .id' | head -n1)
if [ -z "$LAB_ID" ]; then
  echo "Nenhum lab '$LAB_TITLE' encontrado." >&2
  exit 1
fi

# 4. Remoção do Lab: Executa a sequência obrigatória de parada (stop), limpeza (wipe) e exclusão (delete)
echo "==> Removendo lab '$LAB_TITLE' (id=$LAB_ID)..."
curl -sk -X PUT "$BASE_URL/labs/$LAB_ID/stop" -H "$AUTH_HEADER" -o /dev/null -w "    stop  HTTP %{http_code}\n"
curl -sk -X PUT "$BASE_URL/labs/$LAB_ID/wipe" -H "$AUTH_HEADER" -o /dev/null -w "    wipe  HTTP %{http_code}\n"
curl -sk -X DELETE "$BASE_URL/labs/$LAB_ID" -H "$AUTH_HEADER" -o /dev/null -w "    delete HTTP %{http_code}\n"
echo "==> Concluido."
