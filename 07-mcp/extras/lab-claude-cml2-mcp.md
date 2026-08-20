# Lab: Gerenciando o Cisco CML2 com Claude via MCP

## Descrição

Este laboratório demonstra como integrar o **Claude Desktop** com o **Cisco Modeling Labs (CML2)** usando o protocolo **MCP (Model Context Protocol)**. Com essa integração, é possível criar topologias, configurar dispositivos e verificar o funcionamento da rede usando linguagem natural diretamente no chat do Claude.

O servidor MCP utilizado é o [cml-mcp](https://github.com/xorrkaz/cml-mcp), desenvolvido por Joe Clarke (Cisco).

---

## Pré-requisitos

- Claude Desktop instalado no Windows
- Cisco CML2 acessível na rede (versão 2.9 ou superior)
- `uv` / `uvx` instalado no Windows
- WSL com Ubuntu instalado (para uso com PyATS)

---

## Parte 1 — Configurando o Claude Desktop

> ⚠️ **Atenção:** Nos blocos de código abaixo, os valores entre `< >` são placeholders e **devem ser substituídos** pelos dados do seu ambiente antes de executar. Exemplo: `<IP_DO_CML>` → `192.168.1.100`, `<usuario>` → `admin`, `<senha>` → `sua_senha`. Substitua `192.168.1.100` pelo endereço IP do seu CML2. Copiar e colar sem substituir causará erros.

A configuração do MCP é feita pelo menu **Configurações** do Claude Desktop. Acesse com `Ctrl+,` e clique em **Desenvolvedor → Editar Config**. O Windows irá **selecionar o arquivo** `claude_desktop_config.json` no Explorer — abra-o no editor de texto de sua preferência (Notepad, VS Code, etc.).

> É nessa mesma tela de **Desenvolvedor** que você vai verificar se a integração funcionou — o servidor deve aparecer com o badge **running** em azul após reiniciar o Claude Desktop.

### Opção A — Usando PowerShell (sem PyATS)

Use esta opção para gerenciar labs, nodes e links via API do CML. **Não suporta execução de comandos CLI nos dispositivos.**

Antes de configurar, teste se o `uvx` funciona no PowerShell. **Substitua os valores entre `< >` antes de executar:**

```powershell
$env:CML_URL="https://<IP_DO_CML>/"
$env:CML_USERNAME="<usuario>"
$env:CML_PASSWORD="<senha>"
$env:CML_VERIFY_SSL="false"
uvx cml-mcp
```

Se iniciar sem erros, acesse `Ctrl+,` → **Desenvolvedor → Editar Config**, abra o arquivo no editor de sua preferência e substitua o conteúdo por. **Lembre-se de substituir os valores entre `< >` pelos dados do seu ambiente:**

```json
{
  "mcpServers": {
    "Cisco Modeling Labs (CML)": {
      "command": "C:\\Users\\<seu_usuario>\\.local\\bin\\uvx.exe",
      "args": [
        "cml-mcp"
      ],
      "env": {
        "CML_URL": "https://<IP_DO_CML>/",
        "CML_USERNAME": "<usuario>",
        "CML_PASSWORD": "<senha>",
        "CML_VERIFY_SSL": "false"
      }
    }
  }
}
```

> **Nota:** Use o caminho completo do `uvx.exe` porque o Claude Desktop não herda o PATH do usuário no Windows.

---

### Opção B — Usando WSL com Ubuntu (com PyATS) ✅ Recomendado

Esta opção habilita o `send_cli_command`, permitindo executar comandos como `show ip route` diretamente nos dispositivos.

#### 1. Instalar o `uv` nativamente no Ubuntu (WSL)

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

Feche e reabra o terminal WSL. Confirme a instalação:

```bash
uvx --version
# Deve mostrar: uvx x.x.x (x86_64-unknown-linux-gnu)
```

> **Atenção:** Verifique se aparece `linux-gnu` e não `windows-msvc`. Se aparecer `windows-msvc`, o WSL está usando o `uvx` do Windows via PATH compartilhado — a instalação acima corrige isso.

#### 2. Testar o cml-mcp com PyATS no WSL

**Substitua os valores entre `< >` antes de executar:**

```bash
CML_URL="https://<IP_DO_CML>/" \
CML_USERNAME="<usuario>" \
CML_PASSWORD="<senha>" \
CML_VERIFY_SSL="false" \
uvx cml-mcp[pyats]
```

Se aparecer `All tools registered successfully`, está funcionando.

#### 3. Configurar via menu do Claude Desktop

Acesse `Ctrl+,` → **Desenvolvedor → Editar Config**, abra o arquivo no editor de sua preferência e substitua o conteúdo por. **Lembre-se de substituir os valores entre `< >` pelos dados do seu ambiente:**

```json
{
  "mcpServers": {
    "Cisco Modeling Labs (CML)": {
      "command": "wsl",
      "args": [
        "bash", "-c",
        "CML_URL='https://<IP_DO_CML>/' CML_USERNAME='<usuario>' CML_PASSWORD='<senha>' CML_VERIFY_SSL='false' /home/<usuario_linux>/.local/bin/uvx cml-mcp[pyats]"
      ]
    }
  }
}
```

> As variáveis de ambiente são passadas diretamente no comando porque o Claude Desktop não as repassa corretamente para o WSL via bloco `env`.

#### 4. Reiniciar o Claude Desktop

Feche completamente o Claude Desktop pela **bandeja do sistema** (ícone perto do relógio → botão direito → Quit) e reabra. Salvar o arquivo pelo botão **Editar Config** não reinicia o servidor automaticamente — o fechamento completo é necessário.

#### 5. Verificar a conexão

Acesse `Ctrl+,` → **Desenvolvedor**. O servidor **Cisco Modeling Labs (CML)** deve aparecer com o badge **running** em azul.

---

## Parte 2 — Prompts para criar a topologia

Com o MCP conectado e funcionando, use os prompts abaixo em sequência no chat do Claude.

### 2.1 Verificar os labs existentes

```
Liste todos os labs do CML2. Use MCP para isso.
```

### 2.2 Criar a topologia em quadrado com 4 roteadores IOL

```
Crie um novo laboratório chamado "Teste Claude 01".
O laboratório deve ter 4 roteadores IOL formando os vértices de um quadrado.
Os links entre os roteadores são os lados desse quadrado.
Use o endereçamento 10.X.Y.0/24 para ligar os roteadores, onde X e Y são os números dos roteadores.
Exemplo: R1 a R2 usa a rede 10.1.2.0/24.
Crie uma interface loopback em cada roteador com endereço X.X.X.X/24 onde X é o número do roteador.
Ligue o lab e verifique se estão funcionando. Lembre-se de esperar 1 minuto antes de verificar.
```

O Claude irá automaticamente:

1. Criar o lab vazio
2. Adicionar os 4 roteadores IOL posicionados em quadrado no canvas
3. Conectar os 4 links (lados do quadrado)
4. Configurar o endereçamento IP e as loopbacks
5. Iniciar o lab
6. Verificar as interfaces via `show ip interface brief`

**Topologia resultante:**

```
      10.1.2.0/24
 R1 ────────────── R2
 │  (Lo: 1.1.1.1)  │  (Lo: 2.2.2.2)
 │                 │
10.1.3.0/24    10.2.4.0/24
 │                 │
 │  (Lo: 3.3.3.3)  │  (Lo: 4.4.4.4)
 R3 ────────────── R4
      10.3.4.0/24
```

**Endereçamento completo:**

| Link   | Rede          | IP R-esquerdo | IP R-direito |
|--------|---------------|---------------|--------------|
| R1↔R2  | 10.1.2.0/24   | E0/0 → 10.1.2.1 | E0/0 → 10.1.2.2 |
| R1↔R3  | 10.1.3.0/24   | E0/1 → 10.1.3.1 | E0/0 → 10.1.3.3 |
| R2↔R4  | 10.2.4.0/24   | E0/1 → 10.2.4.2 | E0/0 → 10.2.4.4 |
| R3↔R4  | 10.3.4.0/24   | E0/1 → 10.3.4.3 | E0/1 → 10.3.4.4 |

| Roteador | Loopback0  |
|----------|------------|
| R1       | 1.1.1.1/24 |
| R2       | 2.2.2.2/24 |
| R3       | 3.3.3.3/24 |
| R4       | 4.4.4.4/24 |

---

## Parte 3 — Configurando OSPFv2

### 3.1 Prompt para configurar o OSPF

```
Implemente em todos os roteadores o OSPFv2 area 0 e adicione todas as interfaces ao OSPF.
```

O Claude irá configurar em cada roteador:

```
router ospf 1
 network X.X.X.0 0.0.0.255 area 0   ← loopback
 network 10.X.Y.0 0.0.0.255 area 0  ← links diretos
```

### 3.2 Verificando a convergência

Após a configuração, o Claude verifica automaticamente as adjacências e a tabela de rotas. O resultado esperado é:

**Adjacências OSPF (todas em FULL):**

| Vizinhos | Rede         | Estado   |
|----------|--------------|----------|
| R1 ↔ R2  | 10.1.2.0/24  | ✅ FULL  |
| R1 ↔ R3  | 10.1.3.0/24  | ✅ FULL  |
| R2 ↔ R4  | 10.2.4.0/24  | ✅ FULL  |
| R3 ↔ R4  | 10.3.4.0/24  | ✅ FULL  |

**Exemplo de tabela de rotas OSPF no R4:**

```
O  1.1.1.1 [110/21] via 10.3.4.3 e via 10.2.4.2  ← ECMP (2 caminhos)
O  2.2.2.2 [110/11] via 10.2.4.2
O  3.3.3.3 [110/11] via 10.3.4.3
O  10.1.2.0/24 [110/20] via 10.2.4.2
O  10.1.3.0/24 [110/20] via 10.3.4.3
```

> **Observação:** O OSPF calcula dois caminhos de custo igual (ECMP) para destinos opostos no quadrado — comportamento correto e esperado para essa topologia simétrica.

---

## Opção C — macOS (com PyATS) ✅ Mais simples

No macOS o PyATS funciona nativamente, sem necessidade de WSL ou Docker. A configuração é mais direta que no Windows.

### 1. Instalar o `uv`

Abra o Terminal e execute:

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

Feche e reabra o Terminal. Confirme a instalação:

```bash
uvx --version
```

### 2. Descobrir o caminho completo do `uvx`

O Claude Desktop no Mac não herda o PATH do shell, então é necessário usar o caminho completo do executável:

```bash
which uvx
```

O resultado será algo como `/Users/<seu_usuario>/.local/bin/uvx`. Anote esse valor.

### 3. Testar o cml-mcp com PyATS

**Substitua os valores entre `< >` antes de executar:**

```bash
CML_URL="https://<IP_DO_CML>/" \
CML_USERNAME="<usuario>" \
CML_PASSWORD="<senha>" \
CML_VERIFY_SSL="false" \
uvx cml-mcp[pyats]
```

Se aparecer `All tools registered successfully`, está funcionando.

### 4. Configurar via menu do Claude Desktop

Acesse `Cmd+,` → **Desenvolvedor → Editar Config**, abra o arquivo no editor de sua preferência e substitua o conteúdo por. **Lembre-se de substituir os valores entre `< >` pelos dados do seu ambiente:**

```json
{
  "mcpServers": {
    "Cisco Modeling Labs (CML)": {
      "command": "/Users/<seu_usuario>/.local/bin/uvx",
      "args": [
        "cml-mcp[pyats]"
      ],
      "env": {
        "CML_URL": "https://<IP_DO_CML>/",
        "CML_USERNAME": "<usuario>",
        "CML_PASSWORD": "<senha>",
        "CML_VERIFY_SSL": "false"
      }
    }
  }
}
```

> No macOS, diferente do Windows, o bloco `env` funciona corretamente — as variáveis de ambiente são repassadas sem problemas ao processo filho.

### 5. Reiniciar o Claude Desktop

Feche completamente o Claude Desktop (`Cmd+Q`) e reabra.

### 6. Verificar a conexão

Acesse `Cmd+,` → **Desenvolvedor**. O servidor **Cisco Modeling Labs (CML)** deve aparecer com o badge **running** em azul.

---

## Referências

- [cml-mcp no GitHub](https://github.com/xorrkaz/cml-mcp)
- [Model Context Protocol](https://modelcontextprotocol.io)
- [uv — Python package manager](https://docs.astral.sh/uv/)
- [Claude Desktop](https://claude.ai/download)
- [Cisco Modeling Labs](https://www.cisco.com/c/en/us/products/cloud-systems-management/modeling-labs/index.html)
