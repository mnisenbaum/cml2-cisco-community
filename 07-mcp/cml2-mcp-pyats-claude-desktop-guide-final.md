# Guia de Configuração: MCP cml-mcp[pyats] no Claude Desktop (via WSL)

Este guia documenta como conectar o **Claude Desktop** (rodando no Windows) ao **CML2** usando o servidor MCP da comunidade [`cml-mcp`](https://github.com/xorrkaz/cml-mcp) com o extra `[pyats]`, executando-o **dentro do WSL** — já que o `uvx` não funciona bem direto no Windows.

> Servidor MCP: `cml-mcp[pyats]` (comunidade, [xorrkaz/cml-mcp](https://github.com/xorrkaz/cml-mcp))
> Claude Desktop no Windows chama `wsl` → `uvx cml-mcp[pyats]` dentro do WSL
> ✅ Testado e confirmado funcionando

---

## Pré-requisitos

- Claude Desktop instalado no Windows
- WSL2 com Ubuntu configurado
- `uv`/`uvx` instalado dentro do WSL:
  ```bash
  curl -LsSf https://astral.sh/uv/install.sh | sh
  ```
- Acesso ao servidor CML2 em `https://10.10.14.121`
- Dispositivos da topologia com usuário local configurado no startup-config:
  ```
  username cisco privilege 15 secret cisco
  enable secret class
  ```

---

## 1. Configurar o Claude Desktop

Edite o arquivo de configuração do Claude Desktop no Windows:

**Arquivo:** `%APPDATA%\Claude\claude_desktop_config.json`

```json
{
  "mcpServers": {
    "cml2-pyats": {
      "command": "wsl",
      "args": ["bash", "-lc", "uvx cml-mcp[pyats]"],
      "env": {
        "CML_URL": "https://10.10.14.121",
        "CML_USERNAME": "admin",
        "CML_PASSWORD": "Cml2@123",
        "CML_VERIFY_SSL": "false",
        "PYATS_USERNAME": "cisco",
        "PYATS_PASSWORD": "cisco",
        "PYATS_AUTH_PASS": "class",
        "WSLENV": "CML_URL/u:CML_USERNAME/u:CML_PASSWORD/u:CML_VERIFY_SSL/u:PYATS_USERNAME/u:PYATS_PASSWORD/u:PYATS_AUTH_PASS/u"
      }
    }
  }
}
```

### ⚠️ Cuidados essenciais

| Item | Detalhe |
|---|---|
| `command: "wsl"` | O Claude Desktop roda no Windows, então o processo precisa ser lançado dentro do WSL via `wsl` |
| `args: ["bash", "-lc", "uvx ..."]` | `wsl <comando>` sozinho abre uma shell não-interativa/não-login, que **não** carrega o `~/.bashrc`/`~/.profile` — é onde o instalador do `uv` adiciona `~/.local/bin` ao `PATH`. Sem isso, `uvx` não é encontrado ("command not found") mesmo funcionando no login normal do WSL. Usar `bash -lc` força uma shell de login, que carrega o `PATH` corretamente |
| `WSLENV` | **Obrigatório** — é o mecanismo que propaga as variáveis de ambiente do lado Windows para dentro do WSL. Cada variável precisa estar listada aqui, separada por `:`, com o sufixo `/u` (converte o valor para o formato esperado dentro do WSL) |
| Esquecer uma variável no `WSLENV` | A variável chega vazia dentro do WSL — sintoma clássico é `CML_URL not set` mesmo com o valor certo no `env` |
| `CML_USERNAME` / `CML_PASSWORD` | Credencial do **controller** CML2 (API REST) |
| `PYATS_USERNAME` / `PYATS_PASSWORD` / `PYATS_AUTH_PASS` | Credencial **dentro dos dispositivos** da topologia — diferente da credencial do controller |
| `CML_VERIFY_SSL` | `"false"` porque o certificado do CML2 é auto-assinado |

---

## 2. Reiniciar o Claude Desktop

Feche completamente o Claude Desktop (inclusive na bandeja do sistema) e abra de novo para ele reler a config.

---

## 3. Verificar a Conexão

No Claude Desktop, veja o ícone de conectores/MCP na interface — `cml2-pyats` deve aparecer como conectado.

Se não conectar, valide manualmente dentro do WSL:

```bash
CML_URL=https://10.10.14.121 \
CML_USERNAME=admin \
CML_PASSWORD=Cml2@123 \
CML_VERIFY_SSL=false \
PYATS_USERNAME=cisco \
PYATS_PASSWORD=cisco \
PYATS_AUTH_PASS=class \
uvx cml-mcp[pyats]
```

Se esse comando subir o servidor sem erro dentro do WSL, o problema está na ponte Windows→WSL (`WSLENV` ou caminho do `wsl.exe`), não no servidor em si.

---

## 4. Testar Isoladamente com MCP Inspector (opcional)

Rodando dentro do WSL:

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

> Se o WSL não tiver Node.js nativo instalado, o `npx` pode cair no `npx` do Windows via interop e causar `EACCES` ao abrir as portas do Inspector. Solução: instalar Node via `nvm` dentro do WSL.

---

## 5. Troubleshooting

| Sintoma | Causa | Solução |
|---|---|---|
| `CML_URL not set` (ou outras variáveis) dentro do WSL | Variável faltando no `WSLENV` | Conferir se toda variável usada em `env` também está listada no `WSLENV`, com sufixo `/u` |
| Servidor não aparece / erro genérico de conexão | Claude Desktop não recarregou a config | Fechar completamente (bandeja do sistema) e reabrir |
| `uvx: command not found` ao testar `wsl uvx --version` do PowerShell | `wsl <comando>` não carrega `.bashrc`/`.profile`, então `~/.local/bin` (onde o `uv` foi instalado) não entra no `PATH` | Testar com `wsl bash -lc "uvx --version"` — e usar essa mesma forma (`bash -lc "..."`) nos `args` da config |
| `401 Unauthorized` na API do CML2 | `CML_USERNAME`/`CML_PASSWORD` errados | Testar com `curl -k -X POST "https://10.10.14.121/api/v0/authenticate" -H "Content-Type: application/json" -d '{"username":"admin","password":"Cml2@123"}'` dentro do WSL |
| `send_cli_command` falha mesmo com pyATS configurado | Dispositivo sem usuário local no startup-config | Configurar `username cisco privilege 15 secret cisco` e `enable secret class` no nó |
| SSL Error | Certificado auto-assinado | Confirmar `CML_VERIFY_SSL: "false"` |
| Cowork/Code sessions do Claude Desktop dão timeout com este servidor | Comportamento já visto com o MCP nativo `mcp-remote` do CML2 (fluxo OAuth interativo travando em sessão headless) — pode não se aplicar ao `cml-mcp[pyats]`, mas vale checar se ocorrer | Testar a sessão normal do Claude Desktop primeiro; se problema persistir em Cowork/Code, aumentar `timeout` ou revisar logs |

---

## 6. Referências

- [xorrkaz/cml-mcp no GitHub](https://github.com/xorrkaz/cml-mcp)