# Método 5 — SDK oficial (virl2_client)

## Objetivo

Construir a mesma topologia de referência (ver [`00-topologia/topologia-e-enderecamento.md`](../00-topologia/topologia-e-enderecamento.md)) usando o **SDK oficial da Cisco para o CML2**, o pacote [`virl2_client`](https://github.com/CiscoDevNet/virl2-client). Mesmo resultado da Etapa 4 (Python + `requests` cru), mas o SDK cuida de autenticação, sessão HTTP, montagem de URLs e polling de convergência — o script fica mais curto e mais próximo da forma como a Cisco espera que você automatize o CML2 em produção.

## Pré-requisitos

```bash
pip install virl2_client
```

## O script

[`cml_lab_sdk.py`](cml_lab_sdk.py) — mesma interface da Etapa 4:

```bash
python3 cml_lab_sdk.py            # cria o lab de teste e aguarda convergência
python3 cml_lab_sdk.py --cleanup  # remove o lab de teste (stop -> wipe -> remove)
```

### O que muda em relação ao método 4 (requests puro)

| | `requests` puro (Etapa 4) | SDK (`virl2_client`) |
|---|---|---|
| Autenticação | `POST /authenticate` manual, guardar token, montar header em toda chamada | `ClientLibrary(url, username, password, ssl_verify=False)` — faz tudo isso internamente |
| Criar lab | `session.post(".../labs", json=...)`, ler `id` da resposta | `client.create_lab(title=..., description=...)` retorna um objeto `Lab` |
| Criar nó | `session.post(".../nodes", params=..., json=...)` | `lab.create_node(label, "iol-xe", x, y, populate_interfaces=True, configuration=texto)` retorna um objeto `Node` |
| Resolver interface | `GET .../interfaces`, procurar por `label` manualmente num dict | `node.get_interface_by_label("Ethernet0/0")` retorna o objeto `Interface` direto |
| Criar link | `session.post(".../links", json={"src_int": uuid, "dst_int": uuid})` | `lab.create_link(iface_a, iface_b)` — recebe os objetos `Interface`, não UUIDs soltos |
| Esperar pronto | Laço manual de `GET .../lab_element_state` com `time.sleep` | `lab.wait_until_lab_converged()` — já embute o polling |
| Remover | `PUT stop` → `PUT wipe` → `DELETE`, três chamadas manuais | `lab.stop()` → `lab.wipe()` → `lab.remove()` — mesma ordem, mas com nomes de método explícitos em vez de "lembrar a regra" |

O ganho não é só menos linhas — é que o SDK **tipa** o que cada chamada devolve (`Node`, `Interface`, `Lab` como objetos Python com atributos e métodos), em vez de dicts genéricos que exigem lembrar o nome exato de cada chave do JSON.

## Passo a passo

```bash
cd 05-python-sdk
python3 cml_lab_sdk.py
```

Confirme a convergência OSPF pelo console/GUI do CML2:

```
show ip ospf neighbor
show ip route ospf
```

Depois:

```bash
python3 cml_lab_sdk.py --cleanup
```

## Prompt sugerido para o chatbot

> Preciso de um script Python usando o SDK oficial `virl2_client` (não a biblioteca `requests` crua) para criar uma topologia no Cisco CML2: 4 roteadores IOS-XE (R1-R4) em anel, cada um com uma configuração IOS já pronta. Uso: `ClientLibrary(url, username, password, ssl_verify=False)` para conectar; `client.create_lab(title=..., description=...)` retorna um objeto `Lab`; `lab.create_node(label, node_definition, x, y, populate_interfaces=True, configuration=texto)` cria cada nó e retorna um objeto `Node`; `node.get_interface_by_label("Ethernet0/0")` retorna o objeto `Interface`; `lab.create_link(iface_a, iface_b)` cria o link entre duas interfaces; `lab.start()` inicia e `lab.wait_until_lab_converged()` espera todos os nós ficarem prontos. Preciso também de uma limpeza: `lab.stop()` → `lab.wipe()` → `lab.remove()`, nessa ordem. Use `client.find_labs_by_title(titulo)` para checar se já existe um lab de teste antes de criar outro.

Divergência comum a comparar com o gabarito: esquecer que depois de criar os nós com `populate_interfaces=True`, o **modelo local do SDK não sabe das novas interfaces até um `lab.sync()` explícito** — chamar `get_interface_by_label` antes disso lança `InterfaceNotFound` mesmo a interface já existindo no controller (ver Gotcha abaixo).

## Gotchas encontrados validando este roteiro

- **`populate_interfaces=True` cria as interfaces no servidor, mas não no modelo local do SDK.** Chamar `node.get_interface_by_label(...)` logo depois de criar os 4 nós lança `virl2_client.exceptions.InterfaceNotFound`, mesmo a interface existindo (confirmado via API crua). É preciso um `lab.sync()` explícito entre criar os nós e resolver as interfaces para os links — é o que o script faz.
- **O SDK reporta o estado do nó como `BOOTED`, não `STARTED`.** `lab.wait_until_lab_converged()` espera o node chegar em `BOOTED` (SO do roteador realmente terminou de subir, detectado via padrão no console), um sinal de prontidão mais forte que o `STARTED` que os métodos anteriores (bash, PowerShell, Python requests) usam como critério de parada do polling (que só indica que o processo do node começou a rodar). Isso não invalida os métodos anteriores — na prática dá tempo de sobra entre `STARTED` e o aluno checar convergência manualmente — mas é uma diferença real de nível de garantia entre o polling manual e o que o SDK oferece pronto.

## Nota sobre a validação deste roteiro

Script executado de ponta a ponta pelo próprio Claude Code CLI contra o controller real: lab criado, 4 nós com o gabarito (config conferida byte a byte contra `01-manual/respostas-configuracao/`, idêntica), 4 links, `start` + `wait_until_lab_converged()` até `BOOTED` nos 4 nós, depois removido com `--cleanup`. Não foi repetida a checagem manual de convergência OSPF — mesma topologia e mesmo gabarito já confirmados convergindo nos métodos anteriores.
