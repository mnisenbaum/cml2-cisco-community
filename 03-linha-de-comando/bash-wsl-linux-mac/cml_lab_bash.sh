#!/usr/bin/env bash
# Cria a topologia de referencia (losango OSPF, 4 roteadores iol-xe) no CML2
# via API REST, usando so bash + curl + jq. Roda em WSL, Linux ou macOS.
#
# Le CML_URL / CML_USERNAME / CML_PASSWORD de .env na raiz do repositorio.
# Nao remove o lab ao final -- confira a convergencia OSPF manualmente no
# console/GUI antes de rodar a limpeza (ver roteiro-linha-de-comando.md).
# set -euo pipefail é uma boa prática de segurança em Bash:
# -e: aborta o script se qualquer comando falhar (retorno diferente de 0).
# -u: trata variáveis não definidas como erro e aborta.
# -o pipefail: garante que, se um comando num pipe (ex: cmd1 | cmd2) falhar, o status de falha seja propagado.
set -euo pipefail

# 1. Configuração e Dependências: Define caminhos dinâmicos e carrega variáveis
# Obtém a pasta onde este script está salvo e calcula a raiz do repositório
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONFIG_DIR="$REPO_ROOT/01-manual/respostas-configuracao"
ENV_FILE="$REPO_ROOT/.env"

# Define o título do laboratório. O operador :- usa "teste-cli-bash" se LAB_TITLE não estiver definido.
LAB_TITLE="${LAB_TITLE:-teste-cli-bash}"

# Verificação pedagógica: Garante que os alunos tenham jq (leitor/gerador de JSON) e curl instalados
command -v jq >/dev/null || { echo "Precisa de 'jq' instalado." >&2; exit 1; }
command -v curl >/dev/null || { echo "Precisa de 'curl' instalado." >&2; exit 1; }

# LEITURA DO .ENV:
# Usamos grep para achar a linha, cut para pegar a parte após o '=', e o comando 'tr -d \r' 
# para apagar o retorno de carro oculto (\r) caso o .env tenha sido criado/salvo no Windows (CRLF).
CML_URL=$(grep '^CML_URL=' "$ENV_FILE" | cut -d= -f2- | tr -d '\r')
CML_USERNAME=$(grep '^CML_USERNAME=' "$ENV_FILE" | cut -d= -f2- | tr -d '\r')
CML_PASSWORD=$(grep '^CML_PASSWORD=' "$ENV_FILE" | cut -d= -f2- | tr -d '\r')

# O operador %/ remove qualquer barra "/" extra que esteja no final da URL de CML_URL
# para evitar que a concatenação resulte em caminhos como "http://ip//api/v0" (que dá erro 404).
BASE_URL="${CML_URL%/}/api/v0"

# 2. Autenticação: Obtém o token JWT (Bearer Token) da API do CML2
echo "==> Autenticando em $BASE_URL ..."
# -s: silencia o progresso do curl
# -k: ignora validação de certificado SSL autoassinado (insecure)
# -X POST: tipo da requisição HTTP
# -d: dados enviados no corpo (payload JSON)
# tr -d '"': remove as aspas duplas do token JSON retornado no corpo da resposta
TOKEN=$(curl -sk -X POST "$BASE_URL/authenticate" \
  -H "Content-Type: application/json" \
  -d "{\"username\": \"$CML_USERNAME\", \"password\": \"$CML_PASSWORD\"}" \
  | tr -d '"')
[ -n "$TOKEN" ] || { echo "Falha na autenticacao."; exit 1; }
AUTH_HEADER="Authorization: Bearer $TOKEN"
echo "    OK"

# 3. Verificação de Lab Existente: Evita criar lab duplicado
echo "==> Checando se ja existe um lab '$LAB_TITLE'..."
# Fazemos um GET para listar todos os labs e passamos o JSON retornado para o 'jq' filtrar
# --arg t "$LAB_TITLE": cria uma variável interna do jq contendo o nome do lab buscado
# .[] | select(.lab_title == $t) | .id : extrai apenas o UUID do lab correspondente
EXISTING=$(curl -sk "$BASE_URL/labs?show_all=true&with_data=true" -H "$AUTH_HEADER" \
  | jq -r --arg t "$LAB_TITLE" '.[] | select(.lab_title == $t) | .id')
if [ -n "$EXISTING" ]; then
  echo "    ERRO: ja existe lab '$LAB_TITLE' (id=$EXISTING). Remova antes de rodar de novo." >&2
  exit 1
fi
echo "    OK, nenhum lab de teste pre-existente"

# 4. Criação do Laboratório: Cria um laboratório vazio no CML2
echo "==> Criando lab '$LAB_TITLE'..."
# Enviamos o título e descrição, e usamos o 'jq -r .id' para extrair o UUID do novo laboratório
LAB_ID=$(curl -sk -X POST "$BASE_URL/labs" -H "$AUTH_HEADER" -H "Content-Type: application/json" \
  -d "{\"title\": \"$LAB_TITLE\", \"description\": \"Lab de teste da Etapa 3 (linha de comando, trilha bash) -- remover apos confirmacao.\"}" \
  | jq -r '.id')
echo "    lab_id = $LAB_ID"

# 5. Configuração dos Roteadores (Nós):
# declare -A: Declara tabelas hash (arrays associativos) no Bash para guardar coordenadas X/Y e UUIDs dos nós
declare -A NODE_ID
declare -A NODE_X=( [R1]=-440 [R2]=-240 [R3]=-40 [R4]=-240 )
declare -A NODE_Y=( [R1]=-120 [R2]=-320 [R3]=-120 [R4]=80 )

echo "==> Criando os 4 nos (iol-xe) com as configs do gabarito..."
for LABEL in R1 R2 R3 R4; do
  # PEDAGÓGICO: Como criar um JSON válido contendo uma configuração de roteador cheia de quebras de linha?
  # Usar concatenação manual de strings em Bash costuma quebrar o JSON. 
  # Solução elegante: usar 'jq' para montar o objeto JSON.
  # --arg: passa valores como variáveis string do jq.
  # --rawfile: lê o conteúdo do arquivo txt do gabarito de uma vez e injeta como string de forma segura (escapando \n e \r).
  # tonumber: garante que as coordenadas sejam tratadas como inteiros no JSON final.
  BODY=$(jq -n \
    --arg label "$LABEL" \
    --arg x "${NODE_X[$LABEL]}" \
    --arg y "${NODE_Y[$LABEL]}" \
    --rawfile config "$CONFIG_DIR/$LABEL.txt" \
    '{label: $label, node_definition: "iol-xe", x: ($x | tonumber), y: ($y | tonumber), configuration: $config}')
    
  # Faz a criação do nó. O parâmetro populate_interfaces=true na URL solicita ao CML2
  # que crie todas as interfaces de rede padrões do modelo iol-xe.
  NODE_ID[$LABEL]=$(curl -sk -X POST "$BASE_URL/labs/$LAB_ID/nodes?populate_interfaces=true" \
    -H "$AUTH_HEADER" -H "Content-Type: application/json" -d "$BODY" | jq -r '.id')
  echo "    $LABEL -> node_id=${NODE_ID[$LABEL]}"
done

# 6. Mapeamento de Interfaces:
# Explicar para os alunos: Links ligam interfaces por meio de UUIDs únicos, não por nomes.
# Precisamos mapear qual UUID pertence a "Ethernet0/0" e qual pertence a "Ethernet0/1" em cada roteador.
echo "==> Lendo interfaces de cada no para mapear nome -> UUID..."
declare -A IFACE
for LABEL in R1 R2 R3 R4; do
  # Busca todos os dados de interfaces do nó atual
  IFACES_JSON=$(curl -sk "$BASE_URL/labs/$LAB_ID/nodes/${NODE_ID[$LABEL]}/interfaces?data=true&operational=false" -H "$AUTH_HEADER")
  
  # Filtra o JSON para achar os IDs das interfaces físicas que usaremos
  IFACE[${LABEL}_Ethernet0/0]=$(echo "$IFACES_JSON" | jq -r '.[] | select(.label == "Ethernet0/0") | .id')
  IFACE[${LABEL}_Ethernet0/1]=$(echo "$IFACES_JSON" | jq -r '.[] | select(.label == "Ethernet0/1") | .id')
  echo "    $LABEL: Eth0/0=${IFACE[${LABEL}_Ethernet0/0]} Eth0/1=${IFACE[${LABEL}_Ethernet0/1]}"
done

# 7. Criação de Links (Cabos):
# Cria uma função local para conectar dois roteadores usando os UUIDs mapeados
echo "==> Criando os 4 links do losango..."
create_link () {
  local node_a="$1" if_a="$2" node_b="$3" if_b="$4"
  local src="${IFACE[${node_a}_${if_a}]}"
  local dst="${IFACE[${node_b}_${if_b}]}"
  local link_id
  
  # Envia UUIDs de origem (src_int) e destino (dst_int) via POST
  link_id=$(curl -sk -X POST "$BASE_URL/labs/$LAB_ID/links" -H "$AUTH_HEADER" -H "Content-Type: application/json" \
    -d "{\"src_int\": \"$src\", \"dst_int\": \"$dst\"}" | jq -r '.id')
  echo "    $node_a:$if_a <-> $node_b:$if_b -> link_id=$link_id"
}

# Conecta o anel OSPF em losango
create_link R1 Ethernet0/0 R2 Ethernet0/0
create_link R2 Ethernet0/1 R3 Ethernet0/1
create_link R3 Ethernet0/0 R4 Ethernet0/0
create_link R4 Ethernet0/1 R1 Ethernet0/1

# 8. Inicialização e Monitoramento:
echo "==> Iniciando o lab..."
# Aciona o comando de inicialização
curl -sk -X PUT "$BASE_URL/labs/$LAB_ID/start" -H "$AUTH_HEADER" -o /dev/null -w "    HTTP %{http_code}\n"

# POLLING: Aguarda os nós ligarem de fato no CML2.
# Usamos a variável de controle interno do Bash $SECONDS para calcular o timeout sem depender de data/hora do sistema.
echo "==> Aguardando todos os nos ficarem STARTED (polling a cada 5s, timeout 300s)..."
DEADLINE=$((SECONDS + 300))
while [ $SECONDS -lt $DEADLINE ]; do
  # Pega o estado geral dos elementos do laboratório
  STATE=$(curl -sk "$BASE_URL/labs/$LAB_ID/lab_element_state" -H "$AUTH_HEADER")
  echo "    $(echo "$STATE" | jq -c '.nodes')"
  
  # Filtra com jq e conta (wc -l) quantos nós ainda não estão em estado "STARTED"
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
