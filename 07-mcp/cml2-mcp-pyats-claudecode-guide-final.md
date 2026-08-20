# Guia de Configuração: MCP cml-mcp[pyats] no Claude Code

Este guia documenta como conectar o **Claude Code** ao **CML2** usando o servidor MCP da comunidade [`cml-mcp`](https://github.com/xorrkaz/cml-mcp) com o extra `[pyats]`, que além das tools de topologia (labs/nós/interfaces) expõe `send_cli_command` — acesso real ao CLI dos dispositivos dentro do lab via pyATS.

> Servidor MCP: `cml-mcp[pyats]` (comunidade, [xorrkaz/cml-mcp](https://github.com/xorrkaz/cml-mcp))
> Executado via `uvx` — não precisa de venv manual
> Testado em: Claude Code v2.1.226, WSL2 Ubuntu

---

## Pré-requisitos

- Claude Code instalado no WSL (não no Windows — o comando roda dentro do WSL diretamente)
- `uv`/`uvx` instalado no PATH do WSL:
  ```bash
  curl -LsSf https://astral.sh/uv/install.sh | sh
  ```
- Acesso ao servidor CML2 em `https://10.10.14.121`
- Dispositivos da topologia com usuário local configurado no startup-config (necessário para o pyATS conseguir logar via CLI):
  ```
  username cisco privilege 15 secret cisco
  enable secret class
  ```

---

## 1. Registrar o servidor MCP

Dentro do WSL, no diretório do seu projeto (ou fora de um projeto, se preferir escopo global):

```bash
claude mcp add cml2-pyats \
  -e CML_URL=https://10.10.14.121 \
  -e CML_USERNAME=admin \
  -e CML_PASSWORD=Cml2@123 \
  -e CML_VERIFY_SSL=false \
  -e PYATS_USERNAME=cisco \
  -e PYATS_PASSWORD=cisco \
  -e PYATS_AUTH_PASS=class \
  -- uvx cml-mcp[pyats]
```

### ⚠️ Cuidados essenciais

| Item | Detalhe |
|---|---|
| **Não usar `-s project`** | Evita commitar as credenciais em `.mcp.json` dentro do repositório. Sem essa flag, o registro fica no escopo do usuário |
| `CML_USERNAME` / `CML_PASSWORD` | Credencial do **controller** CML2 (autentica na API REST) |
| `PYATS_USERNAME` / `PYATS_PASSWORD` / `PYATS_AUTH_PASS` | Credencial **dentro dos dispositivos** da topologia — diferente da credencial do controller. Só funciona se o startup-config do nó já tiver esse usuário local configurado |
| `CML_VERIFY_SSL` | `false` porque o certificado do CML2 é auto-assinado |
| Reabrir sessão | Depois de registrar, feche e reabra a sessão do `claude` para o servidor aparecer conectado |

---

## 2. Verificar a Conexão MCP

```bash
claude mcp list
```

Deve aparecer `cml2-pyats` com status **Connected**.

Se aparecer como falha, teste a credencial/rede da API do CML2 direto:

```bash
curl -k -X POST "https://10.10.14.121/api/v0/authenticate" \
  -H "Content-Type: application/json" \
  -d '{"username": "admin", "password": "Cml2@123"}'
```

Se retornar um token (string), a API está acessível — o problema está na config do MCP, não na rede/credencial.

---

## 3. Testar Isoladamente com MCP Inspector (opcional)

```bash
npx @modelcontextprotocol/inspector \
  -e CML_URL=https://10.10.14.121 \
  -e CML_USERNAME=admin \
  -e CML_PASSWORD=Cml2@123 \
  -e CML_VERIFY_SSL=false \
  -e PYATS_USERNAME=cisco \
  -e PYATS_PASSWORD=cisco \
  -e PYATS_AUTH_PASS=class \
  uvx cml-mcp[pyats]
```

Abre uma UI web em `localhost:6274` com handshake visual e lista de tools disponíveis.

> Se o WSL não tiver Node.js nativo instalado, o `npx` pode cair no `npx` do Windows via interop e causar `EACCES` ao tentar abrir portas do Inspector. Solução: instalar Node via `nvm` dentro do WSL.

---

## 4. Diferencial em relação ao servidor MCP nativo do CML2

O CML 2.10+ tem um endpoint nativo (`GET /api/v0/ai/mcp/configuration`) que devolve uma config pronta para um servidor `/mcp` embutido no próprio controller (via `mcp-remote`). Ele é diferente do `cml-mcp[pyats]` deste guia:

| | MCP nativo do CML2 (`mcp-remote`) | `cml-mcp[pyats]` (comunidade) |
|---|---|---|
| Tools de topologia (labs, nós, interfaces, links) | ✓ | ✓ |
| Comando CLI real nos dispositivos | ✗ | ✓ (`send_cli_command`, via pyATS) |
| Precisa de credencial separada para os dispositivos | Não | Sim (`PYATS_*`) |
| Requer `mcp-remote` + fluxo de conexão remota | Sim | Não — roda local via `uvx` |

---

## 5. Troubleshooting

| Sintoma | Causa | Solução |
|---|---|---|
| `cml2-pyats` não aparece como Connected após registrar | Sessão do claude não foi reaberta | Fechar e reabrir a sessão do `claude` |
| `401 Unauthorized` na API do CML2 | `CML_USERNAME`/`CML_PASSWORD` errados | Testar com o `curl` da seção 2 |
| `send_cli_command` falha mesmo com pyATS configurado | Dispositivo não tem o usuário local no startup-config | Configurar `username cisco privilege 15 secret cisco` e `enable secret class` no nó |
| SSL Error | Certificado auto-assinado | Confirmar `CML_VERIFY_SSL=false` no registro |
| Credenciais expostas em `.mcp.json` no repositório | Registro feito com `-s project` | Remover o servidor (`claude mcp remove cml2-pyats`) e registrar de novo sem `-s project` |

---

## 6. Referências

- [xorrkaz/cml-mcp no GitHub](https://github.com/xorrkaz/cml-mcp)