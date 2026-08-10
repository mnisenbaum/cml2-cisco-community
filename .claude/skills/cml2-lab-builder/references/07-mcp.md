# Método 7 — MCP

Não gera arquivo/script — a conversa em si constrói o lab, chamando as ferramentas MCP do servidor `cml2` (prefixo `mcp__cml2__`) diretamente.

## Ferramentas relevantes (confirmadas num controller real)

- `mcp__cml2__get_node_definition_detail` — consulta detalhes de uma `node_definition` (ex: interfaces padrão do `iol-xe`).
- `mcp__cml2__create_full_lab_topology` — ferramenta de alto nível: cria o lab inteiro (nós + links + configs) numa chamada só, em vez de nó por nó. Preferir esta em vez de montar nó a nó manualmente, quando disponível.
- `mcp__cml2__add_node_to_cml_lab` / `mcp__cml2__connect_two_nodes` — alternativa passo a passo, se `create_full_lab_topology` não servir para o caso.
- `mcp__cml2__start_cml_lab` (com `wait_for_convergence=true`) — inicia e espera os nós ficarem prontos.
- `mcp__cml2__get_nodes_for_cml_lab` — consulta estado final de cada nó (`BOOTED` esperado).
- `mcp__cml2__stop_cml_lab` / `mcp__cml2__wipe_cml_lab` / `mcp__cml2__delete_cml_lab` — limpeza, nessa ordem.

## Pré-requisito: registrar o servidor MCP

O controller expõe a config pronta em `GET /api/v0/ai/mcp/configuration` (autenticado). O certificado é autoassinado, então **conexão HTTP direta falha** (`DEPTH_ZERO_SELF_SIGNED_CERT`) — usar o bridge que a própria resposta já sugere:

```bash
claude mcp add cml2 \
  -e CML_AUTH_HEADER="Basic <base64 de usuario:senha>" \
  -e NODE_TLS_REJECT_UNAUTHORIZED=0 \
  -- npx -y mcp-remote "https://SEU-CONTROLLER/mcp" --header "X-Authorization:${CML_AUTH_HEADER}"
```

Sem `-s`/`--scope` fica em escopo `local` (não vai pro git). **Depois de registrar, é preciso abrir uma sessão nova** — MCP só conecta na inicialização.

## Comportamento esperado

Usar os 3 fatos do `SKILL.md` (iol-xe, router-id, passive-interface) ao gerar a configuração de cada nó dentro da chamada de criação — o MCP não infere isso sozinho, é preciso incluir explicitamente na configuração passada pra ferramenta de criação de nó/topologia.
