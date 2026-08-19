# Conectando o Claude Code ao MCP do CML2 via WSL — passo a passo

Complementa `07-mcp/roteiro-mcp.md`. Testado em: CML2 2.2.10 (Hyper-V), Claude Code v2.1.226, WSL2 Ubuntu 26.04, acessando o controller (`10.10.14.121`) a partir do WSL.

## Pré-requisitos

- Claude Code instalado no WSL, com rota de rede válida até o CML2.
- Servidor MCP embutido do CML2 habilitado (endpoint `/mcp`).
- `node`/`npx` disponíveis no WSL (usados pelo `mcp-remote`).

## 1. Testar credenciais e rota

```bash
curl -sk https://10.10.14.121/api/v0/authenticate \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"Cml2@123"}'
```

Se retornar um JWT, credenciais e rede estão ok.

## 2. Calcular o header de autenticação

```bash
echo -n "admin:Cml2@123" | base64
```

Resultado usado neste guia: `YWRtaW46Q21sMkAxMjM=`

## 3. Registrar o servidor MCP

```bash
claude mcp add cml2 \
  -e CML_AUTH_HEADER="Basic YWRtaW46Q21sMkAxMjM=" \
  -e NODE_TLS_REJECT_UNAUTHORIZED=0 \
  -- npx -y mcp-remote "https://10.10.14.121/mcp" --header "X-Authorization:\${CML_AUTH_HEADER}"
```

**⚠️ Atenção ao `\$` antes de `{CML_AUTH_HEADER}`.** Essa barra invertida é obrigatória. Sem ela, o bash expande a variável **na hora que você digita o comando** — e como `CML_AUTH_HEADER` normalmente não está definida no seu shell externo (só no bloco `env` do registro), o valor sai vazio. O sintoma é `claude mcp get cml2` mostrando `Args: ... --header X-Authorization:` (sem nada depois dos dois-pontos) e `Status: ✘ Failed to connect`. Com o `\$` escapado, o texto literal `${CML_AUTH_HEADER}` é preservado e o próprio Claude Code faz a expansão em runtime, usando o valor do bloco `env`.

**Por que `mcp-remote` e não conexão HTTP direta?** O certificado do CML2 é autoassinado. Registrar com `--transport http` falha com `DEPTH_ZERO_SELF_SIGNED_CERT` — o Claude Code não tem opção de ignorar certificado nesse modo. `mcp-remote` roda como processo Node local que aceita o certificado (`NODE_TLS_REJECT_UNAUTHORIZED=0`) e faz a ponte via stdio para o Claude Code.

**Escopo:** sem `-s`/`--scope`, o registro fica local (gravado em `~/.claude.json`, fora do repositório). **Nunca** use `-s project` aqui — isso gravaria a senha em `.mcp.json`, arquivo pensado para ser commitado.

## 4. Confirmar o registro

```bash
claude mcp get cml2
```

Espera-se:

```
cml2:
  Scope: Local config (private to you in this project)
  Status: ✔ Connected
  Type: stdio
  Command: npx
  Args: -y mcp-remote https://10.10.14.121/mcp --header X-Authorization:${CML_AUTH_HEADER}
  Environment:
    CML_AUTH_HEADER=Basic YWRtaW46Q21sMkAxMjM=
    NODE_TLS_REJECT_UNAUTHORIZED=0
```

Confira especialmente que o campo `Args` mostra `X-Authorization:${CML_AUTH_HEADER}` **com o `$` presente** — se estiver vazio depois dos dois-pontos, volte ao passo 3 e refaça com o escape correto.

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

Se listar os labs, o MCP está funcionando ponta a ponta. Vale seguir com uma pergunta de verificação:

```
Você usou exclusivamente tools do MCP para obter essa lista?
```

Uma resposta que cite explicitamente as ferramentas usadas (ex.: `mcp__cml2__get_cml_labs`, `mcp__cml2__get_nodes_for_cml_lab`) confirma que os dados vieram do controller real via MCP, e não de suposição ou conhecimento genérico do modelo.

## 8. Criar a topologia de referência

Ver o prompt completo (com a config dos 4 roteadores) em `07-mcp/roteiro-mcp.md`, seção "Passo 3". O assistente deve usar uma ferramenta de alto nível (`create_full_lab_topology`) para criar nós, links e configs numa única chamada.

## Troubleshooting

| Sintoma | Causa provável |
|---|---|
| `Args` mostra `X-Authorization:` sem nada depois, `Status: ✘ Failed to connect` | Faltou escapar o `$` em `\${CML_AUTH_HEADER}` no passo 3 — o bash expandiu a variável vazia antes do registro |
| `DEPTH_ZERO_SELF_SIGNED_CERT` | Tentativa de registro com `--transport http` direto em vez de via `mcp-remote` |
| `cml2` não aparece em `/mcp` | Registro feito, mas a sessão não foi reaberta depois |
| `Missing environment variables: CML_AUTH_HEADER` | Aviso benigno do diagnóstico — ignorar se o status for `connected` |
| `needs authentication` na tela inicial | Conferir qual servidor está com o aviso — pode ser outro conector, não o `cml2` |
| Timeout em sessões Cowork/Code do Claude Desktop | Essas sessões rodam uma cópia isolada/headless do MCP — se cair num fluxo OAuth interativo, trava sem ninguém pra autorizar. O registro via Claude Code CLI (este guia) não sofre desse problema |

## Corrigir um registro quebrado

```bash
claude mcp remove cml2 -s local
```

Depois repita o passo 3 com o comando correto.

## Limpeza (remover de vez)

```bash
claude mcp remove cml2 -s local
```
