# Manual prático do MCP do CML2

Este tutorial ensina como configurar e utilizar o **Model Context Protocol (MCP)** e o **pyATS** para interagir com o seu servidor **Cisco Modeling Labs 2 (CML2)** usando assistentes de IA (como Claude Desktop, Cursor e outros).

---

## 1. O que é o MCP do CML2?

O **Model Context Protocol (MCP)** é um protocolo que atua como uma ponte entre assistentes de IA e ferramentas externas. O servidor open-source [cml-mcp](https://github.com/xorrkaz/cml-mcp) expõe **51 ferramentas** que permitem à IA:
*   **Criar e gerenciar laboratórios** via linguagem natural.
*   **Adicionar, configurar e conectar nós** (como roteadores `iol-xe`, switches e hosts).
*   **Interagir com os dispositivos rodando comandos CLI** via integração nativa com o **pyATS**.
*   **Gerenciar capturas de pacotes (PCAP)** diretamente das interfaces.

---

## 2. Requisitos

Antes de iniciar, certifique-se de que os seguintes componentes estão instalados na máquina onde o cliente MCP será executado:

1.  **Python 3.12+**
2.  **uv** (gerenciador de pacotes rápido do Python)
    *   No Linux/macOS: `curl -LsSf https://astral.sh/uv/install.sh | sh`
    *   No Windows (PowerShell): `irm https://astral.sh/uv/install.ps1 | iex`
3.  **Acesso ao servidor CML2** (neste exemplo, usando `10.10.14.76` e credenciais `admin` / `Cml2@123`).

---

## 3. Configuração nos Clientes de IA

### A. Claude Desktop

Dependendo do seu sistema operacional, localize o arquivo de configuração `claude_desktop_config.json`:

*   **Linux:** `~/.config/Claude/claude_desktop_config.json`
*   **macOS:** `~/Library/Application Support/Claude/claude_desktop_config.json`
*   **Windows:** `%APPDATA%\Claude\claude_desktop_config.json`

Abra o arquivo e insira o seguinte conteúdo JSON:

```json
{
  "mcpServers": {
    "cml": {
      "command": "/home/moises/.local/bin/uvx",
      "args": [
        "cml-mcp[pyats]"
      ],
      "env": {
        "CML_URL": "https://10.10.14.76",
        "CML_USERNAME": "admin",
        "CML_PASSWORD": "Cml2@123",
        "CML_VERIFY_SSL": "false",
        "PYATS_USERNAME": "admin",
        "PYATS_PASSWORD": "Cml2@123"
      }
    }
  }
}
```

> [!IMPORTANT]
> Se o Claude Desktop estiver rodando localmente no Windows ou macOS (fora da máquina Linux), altere o campo `"command"` para o caminho absoluto correspondente do executável `uvx` no seu sistema operacional host (use `which uvx` ou `where uvx` para encontrar o caminho).

---

### B. Cursor

Para configurar diretamente no Cursor via interface visual:

1.  Abra as configurações do Cursor (`Ctrl + ,` ou `Cmd + ,`).
2.  Acesse **Features** > **MCP**.
3.  Clique em **+ Add New MCP Server**.
4.  Configure os campos:
    *   **Name:** `CML`
    *   **Type:** `command`
    *   **Command:** `/home/moises/.local/bin/uvx cml-mcp[pyats]`
5.  Adicione as seguintes variáveis de ambiente (**Env Variables**):

| Variável | Valor |
| :--- | :--- |
| `CML_URL` | `https://10.10.14.76` |
| `CML_USERNAME` | `admin` |
| `CML_PASSWORD` | `Cml2@123` |
| `CML_VERIFY_SSL` | `false` |
| `PYATS_USERNAME` | `admin` |
| `PYATS_PASSWORD` | `Cml2@123` |

6.  Clique em **Save**. O status deve mudar para verde indicando **Connected**.

---

## 4. Automação Local com Python SDK e pyATS

Caso queira criar scripts locais no seu servidor Linux para automatizar tarefas de rede sem um cliente MCP, você já possui um ambiente virtual configurado em `/home/moises/raiz/cml_venv` com o SDK oficial (`virl2_client`) e o `pyats`.

### Exemplo de Script para Validação de Protocolos (ex: OSPF)

Crie um arquivo Python (ex: `verifica_rede.py`) e execute-o com o Python do ambiente virtual:

```python
import urllib3
from virl2_client import ClientLibrary

# Desabilita avisos de certificado autoassinado
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

SERVER = "https://10.10.14.76"
USERNAME = "admin"
PASSWORD = "Cml2@123"

# Conecta ao cliente
client = ClientLibrary(SERVER, USERNAME, PASSWORD, ssl_verify=False)

# Associa-se ao laboratório desejado pelo ID
lab = client.join_existing_lab("78f3de39-6466-4fe2-ae33-786e21293e23")
print(f"Conectado ao Laboratório: {lab.title}")

# Sincroniza o testbed pyATS
lab.pyats.sync_testbed(USERNAME, PASSWORD)

# Executa comando de diagnóstico via pyATS em nós específicos
for nome in ["R1", "R2", "R3", "R4"]:
    try:
        node = lab.get_node_by_label(nome)
        # Verifica se o nó está ligado
        if node.is_active():
            output = node.run_pyats_command("show ip ospf neighbor")
            print(f"\n=== {nome} - show ip ospf neighbor ===")
            print(output)
        else:
            print(f"Nó {nome} está desligado.")
    except Exception as e:
        print(f"Erro ao interagir com {nome}: {e}")
```

Execute o script com:
```bash
/home/moises/raiz/cml_venv/bin/python3 verifica_rede.py
```

---

> [!TIP]
> **Dica de Solução de Problemas:** Se o pyATS falhar ao se conectar aos dispositivos com a mensagem de credenciais incorretas, certifique-se de que os roteadores no CML2 possuem a configuração inicial de `username admin privilege 15 secret Cml2@123` em suas configurações de inicialização (startup config).

---

## 5. Comparação: Execução Direta em Python vs. MCP

Durante a nossa interação, você pode ter notado que eu (sua IA assistente) utilizei scripts em Python direto no terminal em vez de invocar ferramentas MCP. Aqui está o porquê:

*   **Falta de Registro Central:** Para que uma IA consuma o MCP nativamente (com botões de ferramentas no chat), o servidor MCP precisa estar registrado no backend da plataforma de IA. Como o servidor MCP do CML2 não é uma ferramenta nativa global da IA, eu não posso chamá-lo diretamente pelo chat.
*   **Acesso ao Terminal:** Como possuo permissões para rodar comandos na sua máquina (com sua aprovação), posso contornar esse intermediário criando scripts que usam o **`virl2_client`** diretamente no seu ambiente virtual Python (`cml_venv`).
*   **Resultado Idêntico:** O servidor CML MCP nada mais é do que uma "casca" JSON-RPC em cima do SDK Python (`virl2_client`). Logo, o código Python que executo diretamente faz exatamente a mesma coisa que o servidor MCP faria.

---

## 6. Como Testar e Interagir via MCP Manualmente (Sem IA)

Você pode interagir e depurar o protocolo MCP de forma totalmente **manual** e **visual**, sem precisar de nenhuma inteligência artificial. Para isso, você pode usar o **MCP Inspector**, uma ferramenta oficial de depuração que disponibiliza uma interface web local para testar as ferramentas.

### Passo 1: Executar o Inspetor no Terminal

Execute o seguinte comando no terminal da sua máquina configurando as variáveis de conexão com o CML2:

```bash
npx @modelcontextprotocol/inspector \
  -e CML_URL=https://10.10.14.76 \
  -e CML_USERNAME=admin \
  -e CML_PASSWORD=Cml2@123 \
  -e CML_VERIFY_SSL=false \
  -e PYATS_USERNAME=admin \
  -e PYATS_PASSWORD=Cml2@123 \
  uvx cml-mcp[pyats]
```

### Passo 2: Acessar a Interface Gráfica

1.  O comando iniciará um servidor local e exibirá uma URL no terminal (geralmente `http://localhost:6274`).
2.  Abra essa URL no seu navegador.
3.  Acesse a aba **Tools** (Ferramentas). Você verá a lista completa das **51 ferramentas do CML2**.
4.  Você pode preencher os formulários HTML e clicar em **Run Tool** para criar labs, ligar nós, conectar links e rodar comandos CLI de forma direta, manual e visual!

---

## 7. Configuração para OpenCode

O **OpenCode** (agente de IA e extensão do VS Code) funciona de forma similar ao Claude Desktop e Cursor, oferecendo suporte nativo para atuar como hospedeiro (host) de servidores MCP.

Para configurar o MCP do CML2 no OpenCode, você deve adicionar a configuração do servidor ao arquivo `opencode.json` (localizado na raiz do projeto ou na pasta de configuração global do agente, como `~/.opencode/config.json`):

```json
{
  "mcpServers": {
    "cml": {
      "command": "/home/moises/.local/bin/uvx",
      "args": [
        "cml-mcp[pyats]"
      ],
      "env": {
        "CML_URL": "https://10.10.14.76",
        "CML_USERNAME": "admin",
        "CML_PASSWORD": "Cml2@123",
        "CML_VERIFY_SSL": "false",
        "PYATS_USERNAME": "admin",
        "PYATS_PASSWORD": "Cml2@123"
      }
    }
  }
}
```

Após salvar as configurações, reinicie a sessão do agente OpenCode para carregar as novas ferramentas.

---

## 8. Prompts Práticos de Exemplo para Interagir via MCP

Quando estiver usando um cliente com suporte nativo a MCP (como **OpenCode**, **Cursor** ou **Claude Desktop**), a IA não precisará escrever scripts Python para interagir com o CML2. Em vez disso, você deve instruir a IA de maneira que ela faça chamadas diretas às ferramentas injetadas.

Abaixo estão exemplos práticos de prompts que você pode usar para garantir que a IA interaja usando as ferramentas MCP:

### A. Criação de Topologia e Layout
> **Prompt:** *"Crie um novo laboratório chamado 'lab-mcp-teste'. Dentro dele, adicione 4 roteadores iol-xe chamados R1, R2, R3 e R4 distribuídos nos cantos de um quadrado. Conecte-os nos lados do quadrado: R1 a R2, R2 a R3, R3 a R4 e R4 a R1."*

### B. Inicialização e Controle de Dispositivos
> **Prompt:** *"Use as ferramentas de controle de nó para ligar todos os roteadores no laboratório 'lab-mcp-teste' e aguarde até que todos estejam ativos."*

### C. Configuração Básica e Verificação de Interfaces
> **Prompt:** *"Configure o endereço IP 10.1.2.1/24 na interface Ethernet0/0 do R1 e o IP 10.1.2.2/24 na Ethernet0/0 do R2. Em seguida, ative as interfaces (no shutdown) e verifique o status de IP das interfaces de ambos usando o comando de diagnóstico show ip interface brief."*

### D. Resolução de Problemas e Diagnóstico CLI (pyATS)
> **Prompt:** *"Rode a ferramenta de comando CLI pyATS para executar 'show ip ospf neighbor' em todos os roteadores ativos e me diga se há alguma adjacência OSPF estabelecida."*

### E. Captura e Análise de Tráfego
> **Prompt:** *"Inicie uma captura de pacotes (PCAP) no link entre R1 e R2 para coletar tráfego OSPF. Pare a captura após 15 segundos e me traga o resumo do tráfego capturado."*

> [!TIP]
> **Dica para prompts:** Se a IA tentar gerar um script de automação em Python em vez de chamar a ferramenta diretamente, você pode reforçar no prompt: **"Use as ferramentas integradas do CML2 (MCP) para realizar essa tarefa diretamente, sem gerar ou rodar código Python intermediário."**


