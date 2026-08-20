# Guia de Configuração: MCP do CML2 no OpenCode

Este guia documenta o passo a passo para integrar o **Cisco Modeling Labs 2 (CML2)** ao **OpenCode** via MCP (Model Context Protocol), permitindo que o LLM crie e gerencie laboratórios de rede diretamente por comandos em linguagem natural.

> Versão do OpenCode testada: **1.17.4**  
> CML MCP Server: **cml2-88** (Python)

---

## Pré-requisitos

- OpenCode instalado (`~/.opencode/bin/opencode`)
- Acesso a um servidor CML2 (ex: `https://10.10.14.88`)
- Credenciais de admin no CML2
- Python 3.12+ (já incluso no ambiente do CML MCP)

---

## 1. Instalar o CML MCP Server

O CML MCP Server é um pacote Python que implementa o protocolo MCP para se comunicar com a API do CML2.

```bash
# Criar um virtual environment
python3 -m venv ~/cml2-88
source ~/cml2-88/bin/activate

# Instalar o pacote cml-mcp
pip install cml-mcp
```

O comando `cml-mcp` estará disponível em `~/cml2-88/bin/cml-mcp`.

> ⚠️ **Importante**: O CML MCP Server roda em modo `stdio` por padrão — ele não expõe um servidor HTTP, mas sim se comunica via entrada/saída padrão com o OpenCode.

---

## 2. Configurar o OpenCode

Edite o arquivo de configuração global do OpenCode:

**Arquivo:** `~/.config/opencode/opencode.jsonc` (ou `opencode.json`)

```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "cml2": {
      "type": "local",
      "command": ["/home/<usuario>/cml2-88/bin/cml-mcp"],
      "enabled": true,
      "environment": {
        "CML_URL": "https://<ip-do-cml>",
        "CML_USERNAME": "admin",
        "CML_PASSWORD": "<sua-senha>",
        "CML_VERIFY_SSL": "false"
      },
      "timeout": 15000
    }
  }
}
```

### ⚠️ Cuidados essenciais

| Campo | Detalhe |
|-------|---------|
| `command` | Caminho **absoluto** para o binário `cml-mcp` |
| `environment` | O nome do campo é **`environment`** (NÃO `env`). Este foi o bug crítico descoberto durante a implementação |
| `CML_URL` | URL do servidor CML2 sem `/api/v0` no final |
| `CML_VERIFY_SSL` | Use `"false"` se o certificado SSL for auto-assinado |
| `timeout` | Aumente de 5000 (padrão) para 15000ms se o servidor demorar a responder |

---

## 3. Verificar a Conexão MCP

Após configurar, verifique se o OpenCode consegue conectar no servidor MCP:

```bash
opencode mcp list
```

Saída esperada:

```
┌  MCP Servers
│
●  ✓ cml2  connected
│      /home/<usuario>/cml2-88/bin/cml-mcp
│
└  1 server(s)
```

Se o servidor aparecer como **connected**, as tools do CML2 estão disponíveis para uso.

---

## 4. Ferramentas MCP Disponíveis

Com o MCP conectado, o OpenCode expõe as seguintes tools (chamáveis diretamente pelo LLM):

### Laboratórios
| Tool | Descrição |
|------|-----------|
| `get_cml_labs` | Lista todos os labs |
| `get_cml_lab_by_title` | Busca lab por título exato |
| `create_empty_lab` | Cria um lab vazio |
| `modify_cml_lab` | Altera título/descrição/dono |
| `create_full_lab_topology` | Importa topologia completa (JSON/YAML) |
| `clone_cml_lab` | Clona um lab existente |
| `start_cml_lab` | Inicia (boot) um lab |
| `stop_cml_lab` | Para um lab |
| `wipe_cml_lab` | Limpa dados dos nós |
| `delete_cml_lab` | Remove um lab |
| `download_lab_topology` | Exporta topologia como YAML |
| `set_cml_lab_permissions` | Configura permissões de grupos/usuários |

### Nós
| Tool | Descrição |
|------|-----------|
| `get_nodes_for_cml_lab` | Lista nós de um lab |
| `add_node_to_cml_lab` | Adiciona um nó (roteador, switch, etc.) |
| `configure_cml_node` | Aplica startup config |
| `start_cml_node` | Inicia um nó específico |
| `stop_cml_node` | Para um nó específico |
| `wipe_cml_node` | Limpa disco de um nó |
| `delete_cml_node` | Remove um nó |

### Interfaces e Links
| Tool | Descrição |
|------|-----------|
| `get_interfaces_for_node` | Lista interfaces de um nó |
| `add_interface_to_node` | Adiciona interface |
| `connect_two_nodes` | Cria link entre duas interfaces |
| `get_all_links_for_lab` | Lista links do lab |
| `apply_link_conditioning` | Aplica latência, perda, jitter |
| `start_cml_link` | Ativa um link |
| `stop_cml_link` | Desativa um link |

### Descoberta
| Tool | Descrição |
|------|-----------|
| `get_cml_node_definitions` | Lista tipos de nós disponíveis (iosv, csr1000v, etc.) |
| `get_node_definition_detail` | Detalhes de um tipo de nó |

---

## 5. Exemplo: Criar uma Topologia Passo a Passo

Usando as tools MCP diretamente, um laboratório pode ser criado assim:

```
1. "Crie um lab vazio chamado 'Meu Lab OSPF'"
   → create_empty_lab(title="Meu Lab OSPF")
   → Retorna: UUID do lab

2. "Adicione 2 roteadores IOSv chamados R1 e R2 no lab"
   → add_node_to_cml_lab(lab_id, node_definition="iosv", label="R1", x=0, y=0)
   → add_node_to_cml_lab(lab_id, node_definition="iosv", label="R2", x=200, y=0)

3. "Liste as interfaces de R1"
   → get_interfaces_for_node(lab_id, node_id=R1)
   → Retorna: lista com Loopback0, Gi0/0, Gi0/1...

4. "Conecte R1 Gi0/0 a R2 Gi0/0"
   → connect_two_nodes(lab_id, src_int=<id-Gi0/0-R1>, dst_int=<id-Gi0/0-R2>)

5. "Aplique configuração no R1"
   → configure_cml_node(lab_id, node_id=R1, config="...")

6. "Inicie o lab"
   → start_cml_lab(lab_id)
```

---

## 6. Troubleshooting

### ❌ Servidor MCP não conecta (aparece como "error" ou "disconnected")

```bash
opencode mcp list
```

Causas prováveis:

| Sintoma | Causa | Solução |
|---------|-------|---------|
| Servidor aparece mas sem tools | `"env"` usado em vez de `"environment"` | Corrigir para `"environment"` no `opencode.jsonc` |
| Timeout ao conectar | CML2 lento ou timeout padrão (5s) pequeno | Adicionar `"timeout": 15000` |
| `CML_URL not set` | Variáveis de ambiente não passadas | Verificar se o campo é `"environment"` (com `"e"`) |
| `401 Unauthorized` | Credenciais erradas | Verificar `CML_USERNAME` e `CML_PASSWORD` |
| SSL Error | Certificado auto-assinado | Usar `"CML_VERIFY_SSL": "false"` |

### ✅ Teste rápido de conectividade CML2

```bash
curl -k -X POST "https://<cml-ip>/api/v0/authenticate" \
  -H "Content-Type: application/json" \
  -d '{"username": "admin", "password": "Cml2@123"}'
```

Se retornar um token (string), a API do CML2 está acessível.

### 🔍 Logs do MCP Server

Para ativar logs detalhados, adicione no `environment`:

```json
"DEBUG": "true"
```

Isso fará o `cml-mcp` logar cada requisição no stderr (visível nos logs do OpenCode).

---

## 7. Arquitetura

```
┌─────────────┐     MCP (stdio)     ┌──────────────────┐
│  OpenCode   │ ◄──────────────────►│  cml-mcp server   │
│  (LLM + IA) │   JSON-RPC 2.0      │  (Python/FastMCP) │
└─────────────┘                      └────────┬─────────┘
                                              │ HTTP REST
                                              ▼
                                     ┌──────────────────┐
                                     │   CML2 Server     │
                                     │  (API v0)         │
                                     └──────────────────┘
```

O OpenCode inicia o processo `cml-mcp` em segundo plano, passa as variáveis de ambiente configuradas, e se comunica via JSON-RPC 2.0 sobre stdio. O `cml-mcp` traduz as chamadas em requisições HTTP para a API REST do CML2.

---

## 8. Referências

- [Documentação oficial do OpenCode sobre MCP](https://opencode.ai/docs/mcp-servers/)
- [Schema de configuração do OpenCode](https://opencode.ai/config.json)
- [CML2 API Documentation](https://developer.cisco.com/docs/cml/)
- [Model Context Protocol (MCP)](https://modelcontextprotocol.io/)
