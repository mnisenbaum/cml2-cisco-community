# Guia de Configuração: MCP cml-mcp[pyats] no OpenCode

Este guia documenta como conectar o **OpenCode** ao **CML2** usando o servidor MCP da comunidade `cml-mcp` com o extra `[pyats]`, que além das tools de topologia (labs/nós/interfaces) expõe `send_cli_command` — acesso real ao CLI dos dispositivos dentro do lab via pyATS.

> Servidor MCP: `cml-mcp[pyats]` (comunidade, [xorrkaz/cml-mcp](https://github.com/xorrkaz/cml-mcp))
> Executado via `uvx` — não precisa de venv manual

---

## Pré-requisitos

- OpenCode instalado
- `uv`/`uvx` instalado no PATH do WSL:
  ```bash
  curl -LsSf https://astral.sh/uv/install.sh | sh
  ```
- Acesso ao servidor CML2 em `https://10.10.14.121`
- Dispositivos da topologia com usuário local configurado no startup-config (necessário para o pyATS conseguir logar via CLI), por exemplo:
  ```
  username cisco privilege 15 secret cisco
  enable secret class
  ```

---

## 1. Configurar o OpenCode

Edite o arquivo de configuração global do OpenCode:

**Arquivo:** `~/.config/opencode/opencode.jsonc`

```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "cml2-pyats": {
      "type": "local",
      "command": ["uvx", "cml-mcp[pyats]"],
      "enabled": true,
      "environment": {
        "CML_URL": "https://10.10.14.121",
        "CML_USERNAME": "admin",
        "CML_PASSWORD": "Cml2@123",
        "CML_VERIFY_SSL": "false",
        "PYATS_USERNAME": "cisco",
        "PYATS_PASSWORD": "cisco",
        "PYATS_AUTH_PASS": "class"
      },
      "timeout": 15000
    }
  }
}
```

### ⚠️ Cuidados essenciais

| Campo | Detalhe |
|-------|---------|
| `command` | `uvx` baixa e executa o pacote `cml-mcp` com o extra `[pyats]` na hora — não precisa instalar em venv separado |
| `environment` | O nome do campo é **`environment`** (NÃO `env`) — mesma pegadinha do servidor `cml-mcp` simples |
| `CML_USERNAME` / `CML_PASSWORD` | Credencial do **controller** CML2 (autentica na API REST) |
| `PYATS_USERNAME` / `PYATS_PASSWORD` / `PYATS_AUTH_PASS` | Credencial **dentro dos dispositivos** da topologia — diferente da credencial do controller. Só funciona se o startup-config do nó já tiver esse usuário local configurado |
| `CML_VERIFY_SSL` | `"false"` porque o certificado do CML2 é auto-assinado |
| `timeout` | 15000ms — evita timeout se o CML2 demorar a responder |

---

## 2. Verificar a Conexão MCP

```bash
opencode mcp list
```

Saída esperada:

```
┌  MCP Servers
│
●  ✓ cml2-pyats  connected
│      uvx cml-mcp[pyats]
│
└  1 server(s)
```

---

## 3. Testar Isoladamente com MCP Inspector (opcional)

Antes de depender do OpenCode, dá pra validar o servidor sozinho:

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

Isso abre uma UI web em `localhost:6274` com handshake visual e lista de tools disponíveis.

---

## 4. Diferencial em relação ao servidor `cml-mcp` simples

| | `cml-mcp` (simples) | `cml-mcp[pyats]` |
|---|---|---|
| Tools de topologia (labs, nós, interfaces, links) | ✓ | ✓ |
| Comando CLI real nos dispositivos (`send_cli_command`) | ✗ | ✓ |
| Precisa de credencial separada para os dispositivos | Não | Sim (`PYATS_*`) |

---

## 5. Troubleshooting

| Sintoma | Causa | Solução |
|---------|-------|---------|
| Servidor aparece mas sem tools | `"env"` usado em vez de `"environment"` | Corrigir para `"environment"` |
| `401 Unauthorized` na API do CML2 | `CML_USERNAME`/`CML_PASSWORD` errados | Testar com `curl -k -X POST "https://10.10.14.121/api/v0/authenticate" -H "Content-Type: application/json" -d '{"username":"admin","password":"Cml2@123"}'` |
| `send_cli_command` falha mesmo com pyATS configurado | Dispositivo não tem o usuário local no startup-config | Configurar `username cisco privilege 15 secret cisco` e `enable secret class` no nó |
| Timeout ao conectar | CML2 lento ou timeout padrão pequeno | Usar `"timeout": 15000` |
| SSL Error | Certificado auto-assinado | Usar `"CML_VERIFY_SSL": "false"` |

---

## 6. Referências

- [xorrkaz/cml-mcp no GitHub](https://github.com/xorrkaz/cml-mcp)
