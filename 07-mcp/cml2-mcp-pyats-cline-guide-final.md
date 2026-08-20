# Guia de Configuração: MCP cml-mcp[pyats] no Cline (VS Code)

Este guia documenta como conectar o **Cline** (extensão de agente de código para o VS Code) ao **CML2** usando o servidor MCP da comunidade `cml-mcp` com o extra `[pyats]`, que além das tools de topologia (labs/nós/interfaces) expõe `send_cli_command` — acesso real ao CLI dos dispositivos dentro do lab via pyATS.

> Servidor MCP: `cml-mcp[pyats]` (comunidade, [xorrkaz/cml-mcp](https://github.com/xorrkaz/cml-mcp))
> Executado via `uvx` — não precisa de venv manual
> ✅ Testado e confirmado funcionando

---

## ⚠️ Pré-requisito obrigatório: o VS Code precisa estar conectado ao WSL

Este é o ponto que mais gera confusão nessa configuração, então vale repetir antes de qualquer outra coisa: **o Cline precisa estar rodando dentro de uma janela do VS Code aberta via WSL** (Remote — WSL), não numa janela nativa do Windows.

Por quê: a config abaixo chama `uvx` diretamente, sem nenhum wrapper (`wsl bash -lc ...`) — diferente da config equivalente do Claude Desktop, que roda no Windows e por isso *precisa* invocar o WSL explicitamente para cada chamada. O Cline não faz esse pulo sozinho. Se a janela do VS Code estiver aberta nativa do Windows, o Cline vai tentar rodar `uvx` no PowerShell/cmd do Windows — onde ele não existe (o `uv` foi instalado só dentro do WSL) — e o servidor `cml2-pyats` nunca conecta.

Como garantir que está no ambiente certo:

- Abra o projeto de dentro de um terminal WSL com `code .`, **ou**
- No VS Code já aberto, `Ctrl+Shift+P` → **WSL: Connect to WSL** (ou **Reopen Folder in WSL**)
- Confirme no canto inferior esquerdo do VS Code: deve aparecer algo como `WSL: Ubuntu` — se estiver mostrando só o nome da máquina Windows, você está no ambiente errado

Essa é a mesma exigência já documentada para o Cline com o MCP nativo do CML2 (`07-mcp-cline-vscode.md`, via `npx`/`mcp-remote`) — reaproveita o mesmo Node/`npx` (e agora também o `uv`/`uvx`) já validados dentro do WSL.

---

## Pré-requisitos

- Extensão Cline instalada no VS Code.
- Projeto aberto **via WSL** (ver seção acima).
- `uv`/`uvx` instalado no PATH do WSL:
  ```bash
  curl -LsSf https://astral.sh/uv/install.sh | sh
  ```
- Acesso ao servidor CML2 em `https://10.10.14.121`.
- Dispositivos da topologia com usuário local configurado no startup-config (necessário para o pyATS conseguir logar via CLI), por exemplo:
  ```
  username cisco privilege 15 secret cisco
  enable secret class
  ```

---

## 1. Configurar o Cline

Ícone do Cline na barra lateral → **Customize** → aba **MCP** → **Installed** → **Edit Configuration**. Isso abre o `cline_mcp_settings.json`.

Se já existir a entrada `cml2` (MCP nativo do CML2, via `mcp-remote` — ver `07-mcp-cline-vscode.md`), mantenha-a e acrescente `cml2-pyats` dentro do mesmo objeto `mcpServers`:

```json
{
  "mcpServers": {
    "cml2": {
      "command": "npx",
      "args": ["-y", "mcp-remote", "https://10.10.14.121/mcp", "--header", "X-Authorization:${CML_AUTH_HEADER}"],
      "env": {
        "CML_AUTH_HEADER": "Basic YWRtaW46Q21sMkAxMjM=",
        "NODE_TLS_REJECT_UNAUTHORIZED": "0"
      },
      "disabled": false,
      "autoApprove": []
    },
    "cml2-pyats": {
      "command": "uvx",
      "args": ["cml-mcp[pyats]"],
      "env": {
        "CML_URL": "https://10.10.14.121",
        "CML_USERNAME": "admin",
        "CML_PASSWORD": "Cml2@123",
        "CML_VERIFY_SSL": "false",
        "PYATS_USERNAME": "cisco",
        "PYATS_PASSWORD": "cisco",
        "PYATS_AUTH_PASS": "class"
      },
      "disabled": false,
      "autoApprove": []
    }
  }
}
```

### ⚠️ Cuidados essenciais

| Campo | Detalhe |
|---|---|
| `command` | `"uvx"` puro — **sem** `wsl`/`bash -lc` na frente. Só funciona porque o processo do Cline já está rodando dentro do WSL (ver seção acima); nessa condição, `uvx` baixa e executa o pacote `cml-mcp[pyats]` na hora, sem venv separado |
| `env` (não `environment`) | Diferente do OpenCode (que usa a chave `"environment"`), o `cline_mcp_settings.json` segue o mesmo padrão do `claude_desktop_config.json`: a chave é `"env"` |
| `CML_USERNAME` / `CML_PASSWORD` | Credencial do **controller** CML2 (autentica na API REST) |
| `PYATS_USERNAME` / `PYATS_PASSWORD` / `PYATS_AUTH_PASS` | Credencial **dentro dos dispositivos** da topologia — diferente da credencial do controller. Só funciona se o startup-config do nó já tiver esse usuário local configurado |
| `CML_VERIFY_SSL` | `"false"` porque o certificado do CML2 é auto-assinado |
| Sem `WSLENV` | Diferente do Claude Desktop, aqui não existe fronteira Windows→WSL a atravessar — o `env` do próprio Cline injeta as variáveis direto no processo, já dentro do WSL |

---

## 2. Salvar e verificar

Ao salvar, o Cline recarrega a config automaticamente — não precisa reiniciar o VS Code. `cml2-pyats` deve aparecer na lista de servidores instalados, com o indicador de conectado (bolinha verde) e o número de tools carregadas (topologia + `send_cli_command`).

Cada tool tem um checkbox individual de "Auto-approve" — por exemplo, dá para liberar `get_cml_labs` automático e manter `send_cli_command`/`delete_cml_lab` sempre pedindo confirmação.

---

## 3. Testar Isoladamente com MCP Inspector (opcional)

Rodando dentro do WSL, antes de depender do Cline:

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

## 4. Testar no chat do Cline

```
Você tem acesso a um servidor MCP chamado 'cml2-pyats', que expõe a API do Cisco Modeling Labs e comandos de CLI via pyATS. Liste os laboratórios existentes no controller, e se houver algum rodando, rode 'show ip ospf neighbor' em um dos roteadores.
```

---

## 5. Diferencial em relação ao servidor `cml2` (nativo, via `mcp-remote`)

| | `cml2` (nativo CML2, via `mcp-remote`) | `cml2-pyats` (comunidade, via `uvx`) |
|---|---|---|
| Tools de topologia (labs, nós, interfaces, links) | ✓ | ✓ |
| Comando CLI real nos dispositivos (`send_cli_command`) | ✗ | ✓ |
| Precisa de credencial separada para os dispositivos | Não | Sim (`PYATS_*`) |
| Exige o VS Code aberto via WSL | Sim (mesmo Node/`npx`) | Sim (mesmo `uv`/`uvx`) |

---

## 6. Troubleshooting

| Sintoma | Causa | Solução |
|---|---|---|
| `cml2-pyats` não conecta / `uvx: command not found` | VS Code aberto nativo do Windows, não via WSL | `Ctrl+Shift+P` → **WSL: Connect to WSL**, confirmar `WSL: Ubuntu` no canto inferior esquerdo, reabrir o painel MCP |
| Servidor aparece mas sem tools | Chave errada no JSON (`"environment"` em vez de `"env"`) | Corrigir para `"env"` — pegadinha invertida em relação ao OpenCode |
| `401 Unauthorized` na API do CML2 | `CML_USERNAME`/`CML_PASSWORD` errados | Testar com `curl -k -X POST "https://10.10.14.121/api/v0/authenticate" -H "Content-Type: application/json" -d '{"username":"admin","password":"Cml2@123"}'` dentro do WSL |
| `send_cli_command` falha mesmo com pyATS configurado | Dispositivo não tem o usuário local no startup-config | Configurar `username cisco privilege 15 secret cisco` e `enable secret class` no nó |
| SSL Error | Certificado auto-assinado | Confirmar `"CML_VERIFY_SSL": "false"` |
| Botão "Add remote MCP server" não funciona para isso | Esperado — esse formulário não suporta `command`/`args`/`env` locais; use sempre "Edit Configuration" | — |

---

## 7. Referências

- [xorrkaz/cml-mcp no GitHub](https://github.com/xorrkaz/cml-mcp)
- `07-mcp-cline-vscode.md` — configuração do `cml2` nativo (via `mcp-remote`), mesmo requisito de WSL
- `cml2-mcp-pyats-claude-desktop-guide-final.md` — mesma stack `cml-mcp[pyats]`, mas a partir do Windows nativo (por isso precisa do wrapper `wsl bash -lc`)
