# Método 2 — Bruno (cliente de API)

## Objetivo

Construir a mesma topologia de referência (ver [`00-topologia/topologia-e-enderecamento.md`](../00-topologia/topologia-e-enderecamento.md)), desta vez via chamadas HTTP diretas à API REST do CML2, usando o [Bruno](https://www.usebruno.com/) — um cliente de API tipo Postman/Insomnia, mas open-source e com as coleções salvas como arquivos texto (`.bru`), o que dá para versionar em git. É o primeiro contato do curso com a API do CML2: depois deste método, os seguintes (linha de comando, Python, SDK, Terraform, MCP) são variações de automatizar exatamente estas mesmas chamadas.

## Por que Bruno (e não Postman/Insomnia)

- Coleção = pasta de arquivos `.bru` (texto puro), não um JSON monolítico opaco — dá pra revisar diff em PR como qualquer código.
- Não exige conta/login em nuvem para salvar coleção.
- Tem CLI própria (`bru`), então a mesma coleção roda tanto na GUI (uso didático, passo a passo) quanto em terminal/CI (automação, o gabarito deste roteiro foi validado assim).

## Pré-requisitos

- [Bruno desktop](https://www.usebruno.com/downloads) instalado (para seguir o roteiro clicando request por request).
- Opcional, para quem quiser rodar tudo de uma vez como o instrutor validou: `npm install -g @usebruno/cli` (comando `bru`).
- Acesso ao controller CML2 (`CML_URL` do `.env`) e credenciais.

## A coleção

Pasta [`CML2-Lab-Bruno/`](CML2-Lab-Bruno/), com 19 requisições numeradas (a ordem de execução é o campo `seq` de cada `meta`, não o nome do arquivo):

| # | Requisição | O que faz |
|---|---|---|
| 01 | Autenticar | `POST /authenticate` — pega o token JWT e guarda na variável `token` |
| 02 | Criar lab | `POST /labs` com o título de `lab_title` — guarda o `lab_id` |
| 03–06 | Criar nó R1..R4 | `POST /labs/{lab_id}/nodes?populate_interfaces=true` — cria cada roteador `iol-xe` já com a configuração do gabarito (`01-manual/respostas-configuracao/`) embutida no corpo da requisição; guarda o `id` de cada nó (`r1_id`, `r2_id`...) |
| 07–10 | Interfaces de R1..R4 | `GET /labs/{lab_id}/nodes/{node_id}/interfaces?data=true` — lê as interfaces de cada nó e guarda os UUIDs de `Ethernet0/0`/`Ethernet0/1` por nome (`r1_eth00`, `r1_eth01`...) |
| 11–14 | Link R1↔R2, R2↔R3, R3↔R4, R4↔R1 | `POST /labs/{lab_id}/links` usando os UUIDs de interface capturados no passo anterior |
| 15 | Iniciar lab | `PUT /labs/{lab_id}/start` |
| 16 | Consultar estado do lab | `GET /labs/{lab_id}/lab_element_state` — reexecute manualmente até os 4 nós aparecerem `STARTED` |
| 17–19 | Parar / Wipe / Remover lab | Limpeza — só rode depois de conferir a convergência OSPF |

## Encadeamento de variáveis (o conceito central deste método)

Cada requisição que precisa de um dado de uma resposta anterior usa um bloco `script:post-response` para salvar esse dado numa variável de ambiente com `bru.setVar(...)`, e as requisições seguintes reusam com `{{nome_da_variavel}}`. Por exemplo, em `03-criar-no-r1.bru`:

```
script:post-response {
  bru.setVar("r1_id", res.body.id);
}
```

E em `07-interfaces-r1.bru`, o corpo da resposta (lista de interfaces) é varrido para montar um dicionário nome→UUID:

```
script:post-response {
  const byLabel = {};
  res.body.forEach((iface) => { byLabel[iface.label] = iface.id; });
  bru.setVar("r1_eth00", byLabel["Ethernet0/0"]);
  bru.setVar("r1_eth01", byLabel["Ethernet0/1"]);
}
```

Esse padrão — autenticar, guardar token, guardar IDs de recursos criados, referenciar em requisições seguintes — se repete (com sintaxes diferentes) em todos os métodos daqui pra frente.

## Passo a passo

### 1. Abrir a coleção no Bruno

**Open Collection** → aponte para a pasta `02-bruno/CML2-Lab-Bruno/`.

### 2. Configurar o ambiente

No seletor de ambiente (canto superior direito), escolha **controller** e edite:

| Variável | Valor |
|---|---|
| `base_url` | `<CML_URL do seu .env>/api/v0` (ex: `https://172.22.50.230/api/v0`) |
| `cml_username` | seu usuário do CML2 |
| `cml_password` | sua senha — está marcada como **secret** no ambiente: o Bruno guarda o valor localmente e **não** grava no arquivo `.bru` versionado, então cada aluno preenche a própria senha sem risco de vazar no git |
| `lab_title` | `teste-bruno` (ou outro nome identificável, se preferir) |

O certificado do controller é autoassinado — na primeira chamada o Bruno provavelmente vai avisar sobre isso; em **Settings → General**, desative a verificação de certificado SSL para esta coleção (ou marque para confiar nele).

### 3. Rodar request por request

Execute `01` a `15` em ordem, clicando em cada um (ou selecione a coleção inteira e use **Run** para rodar a sequência de uma vez, respeitando o `seq`). Acompanhe as respostas — vale abrir a aba de variáveis do ambiente depois de cada request para ver `token`, `lab_id`, `r1_id`..., `r1_eth00`... sendo preenchidos.

### 4. Esperar os nós subirem

Reexecute `16 - Consultar estado do lab` a cada 15–30s até a resposta mostrar os 4 nós como `STARTED` (leva de 30s a 2 minutos).

### 5. Conferir a convergência OSPF

Pela GUI do CML2 (não pela API — isso fica manual por decisão do curso), abra o console de qualquer roteador e confira, como no método manual:

```
show ip ospf neighbor
show ip route ospf
```

### 6. Limpeza

Só depois de confirmar a convergência, rode `17`, `18` e `19` em ordem (parar → wipe → remover). O CML2 não deixa remover um lab que não passou por `wipe` antes — tentar pular direto pra `19` dá erro `400`.

## Dica: evite duplicar o lab de teste

Se você rodar `02 - Criar lab` mais de uma vez sem remover o lab anterior, o CML2 não impede — ele cria **outro** lab com o mesmo `lab_title` (o título não é único). Se isso acontecer, vá em `GET /labs?show_all=true&with_data=true` (ou a própria GUI) para achar e remover o lab duplicado antes de seguir.

## Prompt sugerido para o chatbot

> Preciso montar uma coleção no Bruno (formato `.bru`, cliente de API open-source parecido com Postman) para automatizar via API REST a criação de uma topologia de 4 roteadores Cisco IOS-XE em anel (R1–R2, R2–R3, R3–R4, R4–R1) no Cisco CML2. A API usa `POST /authenticate` com `{username, password}` retornando um JWT; as chamadas seguintes usam `Authorization: Bearer <token>`. Preciso: criar um lab (`POST /labs` com `{title}`), criar cada nó (`POST /labs/{lab_id}/nodes?populate_interfaces=true` com `{label, node_definition: "iol-xe", x, y, configuration}`, onde `configuration` é o texto da config IOS já pronta), buscar as interfaces de cada nó (`GET /labs/{lab_id}/nodes/{node_id}/interfaces?data=true`, resposta é uma lista de objetos com `id` e `label`, ex: `Ethernet0/0`), criar os links (`POST /labs/{lab_id}/links` com `{src_int, dst_int}` = UUIDs de interface) e iniciar o lab (`PUT /labs/{lab_id}/start`). Preciso que cada requisição capture o dado relevante da resposta (token, lab_id, id de cada nó, UUID de cada interface por nome) numa variável de ambiente do Bruno, usando `script:post-response` com `bru.setVar(...)`, para que as requisições seguintes reusem essas variáveis. Gere os arquivos `.bru` completos, numerados na ordem de execução via `meta.seq`.

Compare com a coleção deste repositório — divergências comuns: esquecer de marcar a senha como variável `secret` no ambiente, ou não montar o dicionário nome→UUID de interface (fácil trocar a ordem dos links sem isso).

## Nota sobre a validação deste roteiro

A coleção foi validada rodando de ponta a ponta pela `bru` CLI contra o controller real (19/19 requisições, todas as assertivas de status HTTP passando). Depois, para conferir a convergência OSPF de fato (não só a mecânica da API), o lab `teste-bruno` foi recriado pela mesma coleção, os nós esperados até `STARTED`, e o usuário confirmou a convergência manualmente no console — só então o lab de teste foi removido.
