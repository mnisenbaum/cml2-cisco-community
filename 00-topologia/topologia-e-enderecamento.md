# Topologia e endereçamento de referência

Esta é a topologia base usada em todos os módulos do workshop. Cada método de automação (manual, API direta, SDK, Terraform, MCP etc.) recria exatamente esta mesma topologia, para que os alunos possam comparar as abordagens sobre um resultado idêntico.

## Visão geral

Quatro roteadores (`R1`, `R2`, `R3`, `R4`), tipo `iol-xe`, ligados em anel (losango): `R1–R2`, `R2–R3`, `R3–R4`, `R4–R1`. Não há malha completa — cada roteador tem exatamente dois vizinhos.

## Endereçamento dos links

Convenção: cada link entre roteadores `x` e `y` (com `x < y`) usa a rede `10.x.y.0/24`, e o host final do IP é o número do próprio roteador.

| Link | Rede | Lado A | Lado B |
|---|---|---|---|
| R1–R2 | 10.1.2.0/24 | R1 Ethernet0/0 = 10.1.2.1 | R2 Ethernet0/0 = 10.1.2.2 |
| R2–R3 | 10.2.3.0/24 | R2 Ethernet0/1 = 10.2.3.2 | R3 Ethernet0/1 = 10.2.3.3 |
| R3–R4 | 10.3.4.0/24 | R3 Ethernet0/0 = 10.3.4.3 | R4 Ethernet0/0 = 10.3.4.4 |
| R4–R1 | 10.1.4.0/24 | R4 Ethernet0/1 = 10.1.4.4 | R1 Ethernet0/1 = 10.1.4.1 |

## Interfaces por roteador

| Roteador | Ethernet0/0 → | Ethernet0/1 → |
|---|---|---|
| R1 | R2 (10.1.2.1) | R4 (10.1.4.1) |
| R2 | R1 (10.1.2.2) | R3 (10.2.3.2) |
| R3 | R4 (10.3.4.3) | R2 (10.2.3.3) |
| R4 | R3 (10.3.4.4) | R1 (10.1.4.4) |

Cada roteador `iol-xe` tem, por padrão, uma interface `Loopback0` e quatro interfaces físicas (`Ethernet0/0` a `Ethernet0/3`). Este lab usa apenas `Ethernet0/0` e `Ethernet0/1` de cada roteador.

## Loopbacks

| Roteador | Loopback0 |
|---|---|
| R1 | 1.1.1.1/24 |
| R2 | 2.2.2.2/24 |
| R3 | 3.3.3.3/24 |
| R4 | 4.4.4.4/24 |

## OSPF

- Processo: `1`
- Área: `0` em todas as interfaces (físicas e loopback)
- Comando de referência por interface: `ip ospf 1 area 0`
- `router-id` explícito em cada roteador, igual ao IP da própria `Loopback0`
- `passive-interface Loopback0` em todos os roteadores (a loopback é anunciada, mas não forma adjacência por ela)

## Posições dos nós no canvas do CML2

Usadas pelos scripts que criam a topologia via API/SDK/Terraform, para reproduzir o mesmo layout visual do lab de referência (`Lab_basico_OSPF.yaml`):

| Roteador | x | y |
|---|---|---|
| R1 | -440 | -120 |
| R2 | -240 | -320 |
| R3 | -40 | -120 |
| R4 | -240 | 80 |

## Definição de nó

- `node_definition`: `iol-xe`
- Interfaces (ids conforme o YAML de referência): `i0` = Loopback0, `i1` = Ethernet0/0, `i2` = Ethernet0/1, `i3` = Ethernet0/2, `i4` = Ethernet0/3

## Fonte

Esta topologia e endereçamento foram definidos pelo instrutor e estão registrados em `Lab_basico_OSPF.yaml`, na imagem `Lab_basico_OSPF-topologia e instrucoes.png` e em `instrucoes.txt`, na raiz do repositório. Este documento é a versão organizada e conferida desses arquivos-fonte — em caso de dúvida futura, os arquivos originais têm precedência.
