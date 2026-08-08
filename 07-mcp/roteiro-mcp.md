# Método 7 — MCP (criar a topologia com linguagem natural)

## Objetivo

Todos os métodos anteriores (Bruno, bash, PowerShell, Python requests, Python SDK, Terraform) automatizam a **mesma sequência fixa de chamadas** — alguém (o instrutor, o aluno) já decidiu antes qual API chamar, em que ordem, com quais parâmetros. O MCP inverte isso: o CML2 expõe suas operações como **ferramentas que um assistente de IA pode escolher e encadear sozinho**, a partir de uma instrução em linguagem natural. Neste método, em vez de rodar um script pronto, o aluno **descreve a topologia para o assistente** (texto, e opcionalmente a imagem de referência) e é o assistente quem decide quais chamadas fazer.

Não é criado um script/gabarito de código aqui — o "gabarito" deste método é o **prompt** e o **registro do servidor MCP**, documentados abaixo.

## O que é o MCP do CML2

O controller expõe um servidor MCP embutido (desde a versão usada aqui — 3.2.4). Ele não precisa de nenhuma instalação separada no lado do CML2: é só uma URL (`/mcp`) que fala o protocolo [MCP](https://modelcontextprotocol.io/) sobre HTTP, autenticada com as mesmas credenciais da API REST.

### Passo 1 — Obter a configuração pronta

```bash
curl -sk https://SEU-CONTROLLER/api/v0/authenticate -H "Content-Type: application/json" \
  -d '{"username":"...","password":"..."}'
# usar o token retornado:
curl -sk https://SEU-CONTROLLER/api/v0/ai/mcp/configuration -H "Authorization: Bearer <token>"
```

Resposta (testada nesta sessão, formato real):

```json
{
  "mcpServers": {
    "Cisco Modeling Labs (CML)": {
      "command": "npx",
      "args": ["-y", "mcp-remote", "https://SEU-CONTROLLER/mcp", "--header", "X-Authorization:${CML_AUTH_HEADER}"],
      "env": {
        "CML_AUTH_HEADER": "Basic <base64_encoded_cml_credentials>",
        "NODE_TLS_REJECT_UNAUTHORIZED": "0"
      }
    }
  }
}
```

O `<base64_encoded_cml_credentials>` é `usuario:senha` em base64 (`echo -n "usuario:senha" | base64`).

### Por que `mcp-remote` e não conexão HTTP direta

O certificado do controller é autoassinado. Testamos registrar o MCP como servidor HTTP direto no Claude Code (`claude mcp add --transport http`) e falhou: `DEPTH_ZERO_SELF_SIGNED_CERT`. O Claude Code não expõe uma opção de "ignorar certificado" para transporte HTTP/SSE direto. `mcp-remote` resolve isso rodando como um processo Node **local** que faz a ponte: ele fala HTTP "de verdade" (com `NODE_TLS_REJECT_UNAUTHORIZED=0`, aceitando o certificado autoassinado) de um lado, e expõe uma interface stdio padrão do outro lado, para o cliente MCP. É exatamente a configuração que o CML2 já devolve pronta em `/ai/mcp/configuration` — não é preciso descobrir isso, só usar.

### Passo 2 — Registrar no Claude Code

```bash
claude mcp add cml2 \
  -e CML_AUTH_HEADER="Basic <base64>" \
  -e NODE_TLS_REJECT_UNAUTHORIZED=0 \
  -- npx -y mcp-remote "https://SEU-CONTROLLER/mcp" --header "X-Authorization:\${CML_AUTH_HEADER}"
```

Sem `-s`/`--scope`, o registro fica no escopo **local** (`claude mcp get cml2` mostra "Local config (private to you in this project)") — específico deste diretório de projeto, gravado em `~/.claude.json` (fora do repositório, nunca vai para o git). **Nunca** registre com `-s project` para este caso — isso gravaria a senha em `.mcp.json`, que é um arquivo pensado para ser commitado.

Confirme a conexão:

```bash
claude mcp get cml2
# Status: ✔ Connected
```

**Depois de registrar um MCP novo, é preciso abrir uma sessão nova do Claude Code** (`claude` de novo, ou reiniciar a sessão atual) — servidores MCP só conectam na inicialização, registrar não faz as ferramentas aparecerem na sessão já em andamento.

### Passo 3 — Pedir a topologia em linguagem natural

Com o MCP conectado, o prompt (numa sessão nova) pode ser algo como:

> Você tem acesso a um servidor MCP chamado 'cml2' que expõe a API do Cisco Modeling Labs (CML2). Use essas ferramentas para criar um novo laboratório chamado 'meu-teste' com a topologia losango OSPF descrita em `00-topologia/topologia-e-enderecamento.md` deste repositório (pode também olhar a imagem `img/Lab_basico_OSPF-topologia e instrucoes.png` como referência visual). São 4 roteadores IOS-XE (node_definition iol-xe): R1, R2, R3, R4, ligados em anel (R1-R2, R2-R3, R3-R4, R4-R1), cada um com a configuração completa que está pronta em `01-manual/respostas-configuracao/R1.txt`, `R2.txt`, `R3.txt`, `R4.txt`. Depois de criar os nós e os links, inicie o laboratório e confirme o estado de cada nó.

Sim, dá pra referenciar a imagem PNG no prompt — o Claude Code lê imagens locais normalmente (é uma ferramenta separada do MCP, mas as duas coexistem na mesma conversa). Neste teste específico, o texto (arquivos de config + descrição da topologia) já era suficiente e determinístico, então não dá pra afirmar que a imagem foi decisiva para o resultado — mas nada impede de apoiar a instrução nela, especialmente se a topologia não estiver descrita em texto em nenhum outro lugar.

## O que aconteceu no teste real deste roteiro

Rodado como uma sessão headless separada (`claude -p`) já com o MCP `cml2` conectado, com o prompt acima (variação com o título `teste-mcp`). O assistente:

1. Chamou `mcp__cml2__get_node_definition_detail` para confirmar as interfaces padrão do `iol-xe`.
2. Chamou **`mcp__cml2__create_full_lab_topology`** — uma ferramenta de alto nível que cria o lab inteiro (nós + links + configs) numa única chamada, em vez da sequência passo a passo (criar lab → criar cada nó → resolver interface → criar cada link) que todos os métodos anteriores precisaram programar manualmente.
3. Chamou `mcp__cml2__start_cml_lab` com `wait_for_convergence=true`.
4. Chamou `mcp__cml2__get_nodes_for_cml_lab` para confirmar o estado final.

Resultado auto-reportado: lab `teste-mcp`, 4 nós `BOOTED`. **Conferido de forma independente** (não só confiando no relato do assistente) via API crua: os 4 links ligam exatamente os pares certos (`R1:Ethernet0/0↔R2:Ethernet0/0`, `R2:Ethernet0/1↔R3:Ethernet0/1`, `R3:Ethernet0/0↔R4:Ethernet0/0`, `R4:Ethernet0/1↔R1:Ethernet0/1`), a configuração de cada nó é idêntica byte a byte ao gabarito, e o estado de todos os 4 nós era `BOOTED`. O usuário também conferiu a convergência OSPF manualmente no console e confirmou.

Ou seja: o conjunto de ferramentas exposto pelo MCP do CML2 não é só um espelho 1:1 da API REST — inclui pelo menos uma operação de mais alto nível (`create_full_lab_topology`) que um assistente pode escolher sozinho para fazer em uma chamada o que os métodos 1-6 deste curso fizeram em vários passos manuais.

## Limpeza

```bash
claude mcp remove cml2 -s local   # se quiser desregistrar o servidor
```

O lab de teste criado durante a validação (`teste-mcp`) foi removido (`stop` → `wipe` → `delete`) depois da confirmação.
