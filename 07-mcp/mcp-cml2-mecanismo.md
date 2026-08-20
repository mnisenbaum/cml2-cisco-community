# Do clique no chat até o roteador responder

6 camadas atravessadas quando uma ferramenta `mcp__remote-devices__cml2-pyats__*` é chamada nesta sessão.

## As 6 camadas

| # | Camada | O que faz |
|---|---|---|
| 1 | **Sessão Cowork (nuvem Anthropic)** — *sem rota até o CML2* | Onde esta conversa acontece. Container Linux isolado, atrás de allowlist restritiva — testado e confirmado: nenhuma rota até a rede do controller nem até a internet pública em geral. Chama a ferramenta pelo nome, ex. `mcp__remote-devices__cml2-pyats__send_cli_command`. |
| 2 | **Ponte `remote-devices`** — *device bridge* | Canal que liga esta sessão ao seu computador, ativo porque o Claude Desktop está aberto na sua máquina. Repassa a chamada de ferramenta para lá e devolve a resposta — é só transporte, não conhece CML2 nem pyATS. |
| 3 | **Claude Desktop (Windows)** — *lê `claude_desktop_config.json`* | No seu Windows. Na inicialização, leu a config e viu o servidor `cml2-pyats` registrado. Ele é quem sabe **como** lançar esse servidor: rodando `wsl bash -lc "uvx cml-mcp[pyats]"` como subprocesso. |
| 4 | **`wsl` → shell de login no Ubuntu** — *`bash -lc`* | O Windows invoca o subsistema WSL2. O `bash -lc` (não só `bash -c`) é essencial: abre uma shell **de login**, que carrega `~/.bashrc`/`~/.profile` — é ali que o instalador do `uv` adicionou `~/.local/bin` ao `PATH`. Sem o `-l`, o comando seguinte falharia com `uvx: command not found`. |
| 5 | **`uvx cml-mcp[pyats]` dentro do WSL** — *uv baixa & roda na hora* | `uvx` (parte da ferramenta **uv**, da Astral) funciona como um `npx` para Python: baixa o pacote comunitário `cml-mcp[pyats]` do índice PyPI e roda na hora, sem instalação permanente. É **dentro do WSL** que isso roda porque só o WSL (não o container de nuvem, nem o Windows nativo — `uvx` não funciona bem direto no PowerShell) tem rota de rede real até o controller CML2. Esse processo expõe as ferramentas MCP usadas: `get_cml_information`, `create_full_lab_topology`, `send_cli_command`, etc. |
| 6 | **CML2 controller — API REST + pyATS/Unicon no console** — *destino final* | O servidor `cml-mcp[pyats]`, de dentro do WSL, fala com a **API REST** do CML2 (criar lab, nós, links, iniciar) usando `CML_USERNAME`/`CML_PASSWORD` — e, para comandos de CLI, abre uma sessão **pyATS/Unicon** no console de cada roteador, logando com `PYATS_USERNAME`/`PYATS_PASSWORD` e entrando em modo privilegiado com `PYATS_AUTH_PASS`. |

## O que o arquivo de configuração informa

`%APPDATA%\Claude\claude_desktop_config.json` — é o único lugar onde as camadas 3, 4 e 5 estão descritas.

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

| Campo | O que informa |
|---|---|
| `command` + `args` | Camadas 3→4→5. Diz ao Claude Desktop para não rodar o servidor MCP direto no Windows, e sim delegar pro WSL, entrando numa shell de *login* (`-lc`) antes de chamar `uvx`. Sem `-l`, o `PATH` do `uv` não carrega. |
| `CML_URL` / `CML_USERNAME` / `CML_PASSWORD` / `CML_VERIFY_SSL` | Credencial do **controller** (API REST). É com isso que o servidor autentica em `/api/v0/authenticate` e cria labs/nós/links. `VERIFY_SSL=false` porque o certificado do CML2 é autoassinado. |
| `PYATS_USERNAME` / `PYATS_PASSWORD` / `PYATS_AUTH_PASS` | Credencial **dentro dos roteadores** (diferente da do controller!). É o `cisco`/`cisco`/`class` configurado no startup-config de cada nó — usado pelo pyATS/Unicon para logar no console e entrar em modo privilegiado ao rodar `send_cli_command`. |
| `WSLENV` | A ponte de variáveis Windows→WSL. O Windows não empurra `env` para dentro do WSL automaticamente; cada variável precisa estar listada aqui (sufixo `/u`) ou chega vazia lá dentro — sintoma clássico: `CML_URL not set` mesmo com o valor certo no `env`. |

---

Baseado em `07-mcp/cml2-mcp-pyats-claude-desktop-guide-final.md` do próprio repositório do curso — configuração testada e confirmada nesta máquina.
