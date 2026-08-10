# Conectando o Cline (VS Code) ao MCP do CML2

Quarta via de acesso ao MCP do CML2, além de Claude Code, OpenCode (ambos em `07-mcp-wsl-conexao.md`) e Claude Desktop (`07-mcp-claude-desktop-windows.md`). [Cline](https://cline.bot) é uma extensão gratuita e open source de agente de código para o VS Code, com painel próprio de MCP.

Testado rodando dentro de uma janela do VS Code conectada via **WSL: Ubuntu** (Remote), reaproveitando o mesmo Node/npx do WSL já validado nos métodos Claude Code e OpenCode.

## Pré-requisitos

- Extensão Cline instalada no VS Code.
- Projeto aberto **via WSL** (não nativo do Windows) — abra com `code .` de dentro do terminal WSL, ou use "Reopen in WSL Container"/"Connect to WSL" no VS Code. Isso garante que o Cline rode no mesmo ambiente onde `npx`/Node já estão confirmados funcionando.
- Mesmas credenciais do CML2 (`admin` / `Cml2@123`) e mesmo IP (`10.208.192.230`) usados nos outros três métodos.

## Por que a GUI não resolve sozinha

O painel MCP do Cline (aba **MCP** → **Installed**) tem um formulário de "Add a remote MCP server": nome, URL e tipo de transporte (Streamable HTTP ou SSE). Ele **não tem campo para header customizado** — não há como passar o `X-Authorization` que o CML2 exige. Mesmo que houvesse, o certificado autoassinado do controller provavelmente derrubaria a conexão de qualquer forma, como aconteceu nos métodos com conexão HTTP direta (ver `07-mcp/roteiro-mcp.md`).

Por isso, o caminho é editar a configuração manualmente — mesmo padrão dos outros três métodos: `mcp-remote` como ponte local (stdio), contornando tanto o certificado quanto a limitação de headers da GUI.

## Passo a passo

### 1. Abrir o painel MCP do Cline

Ícone do Cline na barra lateral → **Customize** → aba **MCP** → **Installed**.

### 2. Editar a configuração

Clique em **Edit Configuration** (não use o formulário "Add a remote MCP server" acima dele). Isso abre o `cline_mcp_settings.json`.

### 3. Adicionar o servidor `cml2`

Se o arquivo estiver vazio ou só com `{}`, cole:

```json
{
  "mcpServers": {
    "cml2": {
      "command": "npx",
      "args": ["-y", "mcp-remote", "https://10.208.192.230/mcp", "--header", "X-Authorization:${CML_AUTH_HEADER}"],
      "env": {
        "CML_AUTH_HEADER": "Basic YWRtaW46Q21sMkAxMjM=",
        "NODE_TLS_REJECT_UNAUTHORIZED": "0"
      },
      "disabled": false,
      "autoApprove": []
    }
  }
}
```

Se já houver outros servidores configurados, acrescente só a entrada `cml2` dentro do objeto `mcpServers` existente.

`${CML_AUTH_HEADER}` é substituído pelo próprio `mcp-remote` em tempo de execução, a partir do bloco `env` — mesma lógica usada nos outros três métodos.

### 4. Salvar

Ao salvar, o Cline recarrega a config automaticamente — não precisa reiniciar o VS Code. O `cml2` deve aparecer na lista de servidores instalados, com o indicador de conectado (bolinha verde) e o número de tools carregadas.

## Resultado real do teste

Funcionou imediatamente após salvar, sem precisar reiniciar nada. O painel listou **47 tools** do `cml2`, cada uma com nome e descrição legível — por exemplo:

- `get_cml_information` — Get server info: version, hostname, system_uptime, ready status, and configuration details.
- `get_cml_status` — Get health status: compute, controller, virl2, and overall system health indicators.
- `get_cml_statistics` — Get resource usage: CPU, memory, disk, running labs/nodes/links counts, and cluster statistics.
- `get_cml_licensing_details` — Get licensing info: registration status, features, node limits, and expiration dates.
- `get_cml_users` — Retrieve all users. Returns list with id, username, fullname, email, admin status, groups, and resource_pool.
- `create_cml_user` — Create user. Requires admin. Returns user UUID.

Cada tool tem um checkbox individual de "Auto-approve", permitindo liberar chamadas automáticas ferramenta por ferramenta (por exemplo, aprovar `get_cml_labs` mas manter `delete_cml_lab` sempre pedindo confirmação).

## Vantagem didática

Diferente dos outros três métodos (onde as tools ficam "escondidas" dentro do fluxo de conversa), o painel do Cline lista todas as 47 tools com descrição, direto na interface — bom para mostrar aos alunos exatamente o que o MCP do CML2 expõe, sem precisar ler o `openapi.json` bruto.

## Testar

No chat do Cline:

```
Você tem acesso a um servidor MCP chamado 'cml2', que expõe a API do Cisco Modeling Labs. Liste os laboratórios existentes no controller e me diga quantos nós cada um tem e em que estado.
```

## Troubleshooting

| Sintoma | Causa provável |
|---|---|
| `cml2` não conecta | Projeto aberto nativo do Windows em vez de via WSL — `npx` do Windows pode não estar disponível ou apontar para outro Node |
| Erro de certificado | Falta `NODE_TLS_REJECT_UNAUTHORIZED: "0"` no bloco `env` |
| Conecta mas 0 tools | Header `X-Authorization` incorreto — confirme o base64 de `usuario:senha` |
| Botão "Add remote MCP server" não funciona | Esperado — esse formulário não suporta headers customizados; use sempre "Edit Configuration" para este caso |