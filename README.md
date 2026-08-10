# CML2 API Access — Curso Progressivo (7 métodos)

Material de aula que ensina, de forma progressiva, todas as formas de acessar a API do Cisco CML2 (Cisco Modeling Labs), usando sempre a **mesma topologia de referência** — um losango OSPF com 4 roteadores IOS-XE (IOL-XE) — recriada uma vez por método, para comparação direta entre abordagens.

Autor: Moisés André Nisenbaum. Material de apoio para apresentação no Cisco Community online.

## Como o curso está organizado

Os 7 métodos avançam em ordem deliberada, de mais manual para mais automatizado — cada um esconde uma camada de mecanismo do anterior. Ver [`08-futuro-chatbot-pedagogico.md`](08-futuro-chatbot-pedagogico.md) para uma reflexão sobre por que essa ordem importa.

| # | Método | O que mostra |
|---|---|---|
| 1 | [Manual](01-manual/roteiro-manual.md) | Construir a topologia pela GUI do CML2, configurando cada roteador pelo console — o ponto de partida, sem nenhuma automação |
| 2 | [Bruno](02-bruno/roteiro-bruno.md) | A mesma topologia via chamadas HTTP explícitas, uma coleção de API navegável e versionável (`.bru`) |
| 3 | [Linha de comando](03-linha-de-comando/roteiro-linha-de-comando.md) | As mesmas chamadas, como script — duas trilhas equivalentes: bash+curl (WSL/Linux/Mac) e PowerShell (Windows nativo) |
| 4 | [Python + requests](04-python-requests/roteiro-python-requests.md) | A mesma sequência numa linguagem de programação de verdade, sem SDK |
| 5 | [Python SDK (`virl2_client`)](05-python-sdk/roteiro-python-sdk.md) | O SDK oficial da Cisco abstrai autenticação, sessão HTTP e polling de convergência |
| 6 | [Terraform](06-terraform/roteiro-terraform.md) | De imperativo para declarativo — descreve o resultado desejado, não a sequência de passos |
| 7 | [MCP](07-mcp/roteiro-mcp.md) | Criar a topologia pedindo em linguagem natural a um assistente de IA conectado ao CML2 via MCP |


> [!WARNING]
> **Autenticação do método 7 (MCP) não é adequada para produção.** O roteiro usa `Basic <base64 de usuario:senha>` como header `X-Authorization`, passado via variável de ambiente (`CML_AUTH_HEADER`) na configuração do cliente MCP. Base64 **não é criptografia** — é uma codificação reversível; qualquer pessoa com acesso ao processo, ao histórico de shell, ou ao arquivo de configuração do cliente (`~/.claude.json`, `opencode.json`, `claude_desktop_config.json`, `cline_mcp_settings.json`, etc.) consegue decodificar a senha em texto puro. Isso é aceitável para um lab local isolado — não para um controller de produção.
>
> Em produção, evite credenciais fixas em arquivos de configuração. Prefira:
> - Segredos vindos de um `.env` não commitado, ou de um gerenciador de segredos (Vault, AWS Secrets Manager, etc.) — como já é feito nos métodos 1-6 deste repositório.
> - Tokens de curta duração obtidos via `/api/v0/authenticate` e renovados periodicamente, em vez de credenciais fixas embutidas na config.
> - Controle de acesso de rede (o `/mcp` não deveria estar exposto além da rede de administração do controller).


Cada roteiro (a partir do método manual) inclui uma seção **"Prompt sugerido para o chatbot"**, para o aluno gerar seu próprio script/coleção com um assistente de IA e comparar com o gabarito testado deste repositório.

## Topologia de referência

Losango (anel de 4 elos): R1–R2, R2–R3, R3–R4, R4–R1 — 4 roteadores IOS-XE, OSPF de área única, endereçamento e configuração completos em [`00-topologia/topologia-e-enderecamento.md`](00-topologia/topologia-e-enderecamento.md). O gabarito de configuração de cada roteador (usado por todos os métodos) está em [`01-manual/respostas-configuracao/`](01-manual/respostas-configuracao/).

## Pré-requisitos gerais

- Acesso a um controller Cisco CML2 (versão testada: 3.2.4) com a definição de nó `iol-xe` disponível.
- Copie [`.env-modelo`](.env-modelo) para `.env`, preencha com a URL e as credenciais do seu controller e renomeie:
  ```
  cp .env-modelo .env
  ```
  **O `.env` nunca é commitado** (está no `.gitignore`) — cada método lê `CML_URL`/`CML_USERNAME`/`CML_PASSWORD` dali, nenhum script ou roteiro deste repositório tem IP ou senha fixos no código.
- O certificado do controller costuma ser autoassinado — cada método trata isso da forma apropriada para sua ferramenta (ver o roteiro correspondente).

Cada método lista, no próprio roteiro, os pré-requisitos específicos (bibliotecas Python, Terraform, Bruno, etc).

## Verificação de convergência OSPF

Por decisão do curso, a criação da topologia é sempre automatizada e verificada via API (nós chegando a `STARTED`/`BOOTED`), mas a **confirmação de que o OSPF convergiu** (`show ip ospf neighbor`, `show ip route ospf`) é sempre manual, pelo console ou GUI do CML2 — nenhum método usa SSH/console de forma automatizada para isso.

## Estrutura do repositório

```
00-topologia/            topologia e endereçamento de referência
01-manual/                gabarito de configuração + roteiro do método manual
02-bruno/                 coleção Bruno (.bru) + roteiro
03-linha-de-comando/      scripts bash e PowerShell + roteiro
04-python-requests/       script Python (requests) + roteiro
05-python-sdk/            script Python (virl2_client) + roteiro
06-terraform/             main.tf/variables.tf/outputs.tf + roteiro
07-mcp/                   roteiro de uso do MCP embutido do CML2
08-futuro-chatbot-pedagogico.md   reflexão final
```
