# Módulo 5 — MCP + linguagem natural — 10 min

Objetivo: construir a mesma topologia ([losango OSPF](../00-topologia/README.md)) sem escrever nenhum código — apenas **pedindo em português** para um chatbot com acesso ao CML2 via **MCP** (Model Context Protocol).

## O que é MCP e o que muda aqui

Nos módulos 2, 3 e 4, nós (humanos) escrevemos o código que chama a API. Com MCP, um servidor especializado expõe a API do CML2 como um conjunto de **ferramentas** que um assistente de IA (Claude Desktop, Cursor, LM Studio, etc.) pode chamar sozinho, a partir do que você pede em linguagem natural. Você descreve o resultado desejado; o modelo decide quais chamadas fazer.

O CML **2.10** trouxe dois pedaços dessa história:

1. Um **servidor MCP oficial para CML**, o [`cml-mcp`](https://github.com/xorrkaz/cml-mcp) (Cisco, código aberto, `pip`/`uvx`), com ~50 ferramentas: criar labs, adicionar nós, conectar interfaces, configurar dispositivos, iniciar/parar labs, rodar comandos via PyATS, capturar pacotes, anotações visuais etc.
2. Um endpoint nativo da API, **`GET /ai/mcp/configuration`**, que devolve um bloco de configuração MCP já pronto para colar no seu cliente (Claude Desktop e similares usam o mesmo formato `mcpServers`).

## Passo a passo

### 1. Pré-requisitos

- [`uv`/`uvx`](https://docs.astral.sh/uv/) instalado (`uvx` baixa e roda o `cml-mcp` sob demanda, sem instalação manual).
- Um cliente MCP (ex.: Claude Desktop).
- Python 3.12/3.13 se for usar `pyats` para executar comandos CLI nos roteadores via chat.

### 2. Obter a configuração pronta da sua instância

Com o token da API (mesma autenticação dos módulos 2/3), busque a configuração sugerida pelo próprio CML2:

```bash
set -a; source ../.env; set +a

TOKEN=$(curl -k -s -X POST "$CML_HOST/api/v0/authenticate" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"$CML_USERNAME\",\"password\":\"$CML_PASSWORD\"}" | tr -d '"')

curl -k -s "$CML_HOST/api/v0/ai/mcp/configuration" \
  -H "Authorization: Bearer $TOKEN" | jq .
```

A resposta é um objeto `mcpServers` no mesmo formato usado pelo `claude_desktop_config.json`.

### 3. Configurar o cliente MCP (exemplo: Claude Desktop)

Abra o arquivo de configuração do cliente:

- **macOS**: `~/Library/Application Support/Claude/claude_desktop_config.json`
- **Windows**: `%APPDATA%\Claude\claude_desktop_config.json`
- **Linux**: `~/.config/Claude/claude_desktop_config.json`

E adicione (ou cole o resultado do passo 2, ajustando as credenciais):

```json
{
  "mcpServers": {
    "Cisco Modeling Labs (MCP)": {
      "type": "stdio",
      "command": "uvx",
      "args": ["cml-mcp[pyats]"],
      "env": {
        "CML_URL": "https://10.10.14.76",
        "CML_USERNAME": "admin",
        "CML_PASSWORD": "Cml2@123",
        "CML_VERIFY_SSL": "false"
      }
    }
  }
}
```

> Se `uvx` não for encontrado pelo cliente (PATH restrito), use o caminho completo — descubra com `which uvx` (macOS/Linux) ou `where uvx` (Windows).

Reinicie o cliente MCP para carregar o servidor.

### 4. Construir o losango OSPF por linguagem natural

Com o CML2 conectado, peça em conversas sucessivas (ou em um único pedido bem descritivo):

1. `"Crie um novo lab no CML2 chamado 'Losango OSPF - MCP'."`
2. `"Adicione 4 roteadores IOL-XE nesse lab, chamados R1, R2, R3 e R4, posicionados em formato de losango (R1 no topo, R2 à direita, R3 embaixo, R4 à esquerda)."`
3. `"Conecte R1-R2, R2-R3, R3-R4 e R4-R1, formando um anel fechado sem diagonais."`
4. `"Configure cada roteador com uma interface Loopback0 com endereço /32 (1.1.1.1 em R1, 2.2.2.2 em R2, 3.3.3.3 em R3, 4.4.4.4 em R4) e habilite OSPF área 0 em todas as interfaces, incluindo a loopback. Use as redes 10.1.2.0/24 entre R1 e R2, 10.2.3.0/24 entre R2 e R3, 10.3.4.0/24 entre R3 e R4 e 10.4.1.0/24 entre R4 e R1."`
5. `"Inicie o lab e, quando todos os nós estiverem BOOTED, mostre os vizinhos OSPF de R1."`

O assistente vai encadear as ferramentas do `cml-mcp` (`create_empty_lab`, `add_node_to_cml_lab`, `connect_two_nodes`, `configure_cml_node`, `start_cml_lab`, `send_cli_command`...) para chegar no resultado — a mesma topologia dos 4 módulos anteriores.

### 5. Validar

Peça diretamente pelo chat:

```
Mostre a config atual de R1.
Rode "show ip ospf neighbor" em R1, R2, R3 e R4.
Rode "show ip route ospf" em R1.
```

O assistente usa `send_cli_command` (via PyATS) para executar e trazer a saída de volta para a conversa.

## Pontos para discutir no workshop

- Esse é o mesmo resultado dos módulos 1–4, mas sem escrever uma linha de código ou HCL — só descrição do que se quer.
- Por baixo dos panos, o `cml-mcp` está fazendo exatamente as mesmas chamadas REST do módulo 2 (o `openapi.json` continua sendo a "verdade" da API).
- Ganha-se velocidade e acessibilidade (qualquer pessoa pode "programar" o lab); perde-se um pouco de previsibilidade determinística — vale conferir o resultado (passo 5) sempre que usar essa abordagem.
- Essa é também a porta de entrada para agentes de IA que fazem troubleshooting: "por que OSPF não sobe entre R2 e R3?" pode virar um diagnóstico automatizado.
