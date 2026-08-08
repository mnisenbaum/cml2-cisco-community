# Método 4 — Python + requests

## Objetivo

Construir a mesma topologia de referência (ver [`00-topologia/topologia-e-enderecamento.md`](../00-topologia/topologia-e-enderecamento.md)) com um script Python usando a biblioteca [`requests`](https://requests.readthedocs.io/) — sem SDK oficial do CML2 (isso vem na Etapa 5). É a mesma sequência de chamadas HTTP dos métodos anteriores (Bruno, bash, PowerShell), agora expressa numa linguagem de programação de verdade: variáveis normais em vez de `bru.setVar`/variáveis de ambiente, laços e condicionais de Python em vez de reexecução manual.

## Pré-requisitos

```bash
pip install requests
```

(`urllib3` já vem junto como dependência do `requests` — usado só para silenciar o aviso de certificado autoassinado.)

## O script

[`cml_lab_requests.py`](cml_lab_requests.py) — um único arquivo, dois modos:

```bash
python3 cml_lab_requests.py            # cria o lab de teste e aguarda STARTED
python3 cml_lab_requests.py --cleanup  # remove o lab de teste (stop -> wipe -> delete)
```

Lê `CML_URL`/`CML_USERNAME`/`CML_PASSWORD` de `.env` na raiz do repositório (nunca hardcoda o IP do controller), trata barra final em `CML_URL` e `\r` residual (arquivo pode ter sido salvo com CRLF no Windows).

### Estrutura do script

- `load_env()` — parser simples de `.env` (não usa `python-dotenv` de propósito, para o aluno ver o parsing explícito).
- `make_session()` — autentica (`POST /authenticate`) e devolve uma `requests.Session()` já com o header `Authorization: Bearer <token>` configurado — todas as chamadas seguintes reusam essa sessão, sem repetir o header manualmente.
- `find_lab_id()` — usado tanto para checar duplicata antes de criar quanto para localizar o lab na hora do cleanup (lembrando: título de lab não é único no CML2, então essa checagem evita lixo acumulado no controller).
- `create_lab()` — cria o lab, os 4 nós (com a config do gabarito embutida), resolve os UUIDs de interface por nome, cria os 4 links, inicia e faz polling do estado até `STARTED`.
- `cleanup()` — `stop` → `wipe` → `delete`, nessa ordem (o CML2 rejeita `delete` direto num lab que não passou por `wipe`).

Cada chamada usa `resp.raise_for_status()` — se a API retornar erro, o script para imediatamente com o traceback da chamada que falhou, em vez de continuar com dados incompletos.

## Passo a passo

```bash
cd 04-python-requests
python3 cml_lab_requests.py
```

Acompanhe a saída (mesma lógica de progresso das etapas anteriores: autenticar, criar lab, criar nós, resolver interfaces, criar links, iniciar, polling). Ao final, confirme a convergência OSPF pelo console/GUI do CML2:

```
show ip ospf neighbor
show ip route ospf
```

Depois:

```bash
python3 cml_lab_requests.py --cleanup
```

## Prompt sugerido para o chatbot

> Preciso de um script Python usando a biblioteca `requests` (não uma SDK específica) para automatizar a criação de uma topologia no Cisco CML2 via API REST: 4 roteadores IOS-XE (R1-R4) ligados em anel, cada um com uma configuração IOS já pronta (string multi-linha) enviada no corpo da requisição de criação do nó. A API: `POST /authenticate` com `{username, password}` retorna um JWT usado como `Authorization: Bearer <token>` nas chamadas seguintes; `POST /labs` com `{title}` cria o lab e retorna `{id}`; `POST /labs/{lab_id}/nodes?populate_interfaces=true` com `{label, node_definition: "iol-xe", x, y, configuration}` cria cada nó; `GET /labs/{lab_id}/nodes/{node_id}/interfaces?data=true` retorna uma lista de objetos `{id, label}` (preciso pegar o `id` de `Ethernet0/0` e `Ethernet0/1` de cada nó); `POST /labs/{lab_id}/links` com `{src_int, dst_int}` (UUIDs de interface) cria cada link; `PUT /labs/{lab_id}/start` inicia o lab; `GET /labs/{lab_id}/lab_element_state` retorna o estado de cada nó (preciso fazer polling até todos ficarem `STARTED`, com timeout). O certificado do controller é autoassinado. Quero usar uma `requests.Session()` para não repetir o header de autenticação em toda chamada, e `raise_for_status()` para falhar rápido se alguma chamada der erro. Gere também um modo de limpeza que remove o lab (`stop` → `wipe` → `delete`, nessa ordem exata — o CML2 rejeita `delete` direto).

Divergências comuns a comparar com o gabarito: esquecer `session.verify = False` (ou usar sem silenciar o `InsecureRequestWarning`), não reusar a `Session` (repetir o header em cada chamada manualmente), ou tentar `delete` sem `stop`/`wipe` antes.

## Nota sobre a validação deste roteiro

Script executado de ponta a ponta pelo próprio Claude Code CLI contra o controller real: lab criado, 4 nós com o gabarito, 4 links, `start`, todos os nós confirmados `STARTED` por polling, e depois removido com `--cleanup` (stop/wipe/delete, todos OK). Não foi repetida a checagem manual de convergência OSPF — mesma topologia e mesmo gabarito já confirmados convergindo em 3 métodos anteriores (manual, Bruno, linha de comando bash).
