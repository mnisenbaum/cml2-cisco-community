# Conectando o Claude Code ao MCP do CML2 via WSL — passo a passo

Complementa `07-mcp/roteiro-mcp.md`. Testado em: CML2 2.2.10 (Hyper-V), Claude Code v2.1.226, WSL2 Ubuntu, acessando o controller a partir do WSL.

## Pré-requisitos

- Claude Code instalado no WSL, com rota de rede válida até o CML2.
- Servidor MCP embutido do CML2 habilitado (endpoint `/mcp`).
- `node`/`npx` disponíveis no WSL (usados pelo `mcp-remote`).

## 1. Testar credenciais e rota

```bash
curl -sk https://<IP-DO-CML2>/api/v0/authenticate \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"<senha>"}'
```

Se retornar um JWT, credenciais e rede estão ok.

## 2. Calcular o header de autenticação

```bash
echo -n "admin:<senha>" | base64
```

## 3. Registrar o servidor MCP

```bash
claude mcp add cml2 \
  -e CML_AUTH_HEADER="Basic <base64 do passo 2>" \
  -e NODE_TLS_REJECT_UNAUTHORIZED=0 \
  -- npx -y mcp-remote "https://<IP-DO-CML2>/mcp" --header "X-Authorization:\${CML_AUTH_HEADER}"
```

**Por que `mcp-remote` e não conexão HTTP direta?** O certificado do CML2 é autoassinado. Registrar com `--transport http` falha com `DEPTH_ZERO_SELF_SIGNED_CERT` — o Claude Code não tem opção de ignorar certificado nesse modo. `mcp-remote` roda como processo Node local que aceita o certificado (`NODE_TLS_REJECT_UNAUTHORIZED=0`) e faz a ponte via stdio para o Claude Code.

**Escopo:** sem `-s`/`--scope`, o registro fica local (gravado em `~/.claude.json`, fora do repositório). **Nunca** use `-s project` aqui — isso gravaria a senha em `.mcp.json`, arquivo pensado para ser commitado.

## 4. Confirmar o registro

```bash
claude mcp get cml2
```

Espera-se `Status: ✔ Connected`.

## 5. Abrir uma sessão nova

Servidores MCP só conectam na inicialização. Depois de registrar, feche e rode `claude` de novo (ou abra outra sessão) — registrar não faz as ferramentas aparecerem numa sessão já em andamento.

## 6. Verificar dentro do Claude Code

Dentro da sessão, rode:

```
/mcp
```

Deve aparecer `cml2 · ✔ connected · N tools`.

Dois avisos que podem aparecer e **não são problema**:

- `Missing environment variables: CML_AUTH_HEADER` — o diagnóstico checa o ambiente do shell, não o bloco `env` do próprio registro (que é onde o `mcp-remote` de fato lê a variável). Se `cml2` estiver `connected`, ignore.
- `⚠ needs authentication` na tela inicial — confira **de qual servidor** é antes de se preocupar. Pode ser outro conector (ex.: Canva do claude.ai) sem nenhuma relação com o CML2.

## 7. Teste rápido

Prompt simples, sem depender de nenhum arquivo do repositório:

```
Você tem acesso a um servidor MCP chamado 'cml2', que expõe a API do Cisco Modeling Labs. Liste os laboratórios existentes no controller e me diga quantos nós cada um tem e em que estado.
```

Se listar os labs, o MCP está funcionando ponta a ponta.

## 8. Criar a topologia de referência

Ver o prompt completo (com a config dos 4 roteadores) em `07-mcp/roteiro-mcp.md`, seção "Passo 3". O assistente deve usar uma ferramenta de alto nível (`create_full_lab_topology`) para criar nós, links e configs numa única chamada.

## Resultado real do teste (passo 7)

Prompt usado: o do passo 7 acima. Resposta do Claude Code, listando os 4 laboratórios existentes no controller e o estado de cada nó:

| Laboratório | Estado do lab | Nós | Estado dos nós |
|---|---|---|---|
| Lab at Sun 19:18 PM | STOPPED | 6 (chrome-0, firefox-0, dnsmasq-0, radius-0, nginx-0, net-tools-0) | Todos STOPPED |
| Lab Quadrado Routers | DEFINED_ON_CORE | 4 (R1, R2, R3, R4 — iosv) | Todos DEFINED_ON_CORE |
| Lab basico OSPF | DEFINED_ON_CORE | 4 (R1, R2, R3, R4 — iol-xe) | Todos DEFINED_ON_CORE |
| Lab basico OSPF - teste pyats | STOPPED | 4 (R1, R2, R3, R4 — iol-xe) | Todos STOPPED |

Pergunta de verificação feita em seguida: *"você usou exclusivamente tools do MCP para obter essa lista?"* — resposta confirmada:

> Sim. Usei exclusivamente duas tools do MCP cml2:
> 1. `mcp__cml2__get_cml_labs` — para listar os 4 laboratórios (id, título, estado, node_count).
> 2. `mcp__cml2__get_nodes_for_cml_lab` — chamada uma vez para cada um dos 4 labs (passando o lid/UUID de cada um), para obter o detalhe e o estado individual dos nós.
> Não usei Bash, WebFetch nem nenhuma outra fonte — todos os dados vieram diretamente das respostas dessas duas chamadas ao controller CML via MCP.

Essa checagem — perguntar explicitamente se o assistente usou só ferramentas do MCP — é um bom hábito para qualquer teste deste tipo: confirma que a resposta veio do controller real, e não de suposição ou de conhecimento genérico do modelo.

## Troubleshooting rápido

| Sintoma | Causa provável |
|---|---|
| `DEPTH_ZERO_SELF_SIGNED_CERT` | Tentativa de registro com `--transport http` direto em vez de via `mcp-remote` |
| `cml2` não aparece em `/mcp` | Registro feito, mas a sessão não foi reaberta depois |
| `Missing environment variables: CML_AUTH_HEADER` | Aviso benigno do diagnóstico — ignorar se o status for `connected` |
| `needs authentication` na tela inicial | Conferir qual servidor está com o aviso — pode ser outro conector, não o `cml2` |

## Limpeza

```bash
claude mcp remove cml2 -s local
```