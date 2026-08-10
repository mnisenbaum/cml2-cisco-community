---
name: cml2-lab-builder
description: Ajuda a gerar os artefatos de automação do curso CML2 "losango OSPF" (config CLI manual, coleção Bruno, scripts bash/PowerShell, Python requests, Python SDK virl2_client, Terraform) e a conduzir a criação do lab via MCP. Use sempre que o usuário mencionar este curso/repositório cml2-cisco-community, anexar/referenciar a imagem "Lab_basico_OSPF-topologia e instrucoes.png", pedir para gerar um dos 7 métodos de automação do CML2 a partir da topologia, ou pedir para montar/criar esse lab via MCP do CML2.
---

# CML2 lab builder

Gera o artefato de automação certo (config, coleção, script, IaC) para a topologia de referência do curso CML2 — a partir da imagem `Lab_basico_OSPF-topologia e instrucoes.png` (ou de uma descrição equivalente em texto), sem precisar que o usuário repita no prompt o que já está na imagem.

## A topologia (o que a imagem já mostra)

4 roteadores em anel (losango): R1–R2, R2–R3, R3–R4, R4–R1. Cada link usa `Ethernet0/0` de um lado e `Ethernet0/1` do outro (ver rótulos na imagem — cada roteador usa uma interface física diferente para cada vizinho). Regras de endereçamento (bloco "Instruções" da imagem):

1. Link entre roteadores `x` e `y` (`x < y`): rede `10.x.y.0/24`, host = número do próprio roteador. Ex: R2↔R3 = `10.2.3.2` / `10.2.3.3`.
2. Loopback0 de cada roteador `x`: `x.x.x.x/24`. Ex: Loopback0 de R4 = `4.4.4.4/24`.
3. OSPF área 0 em todas as interfaces de todos os roteadores.

## Os 3 fatos que a imagem NÃO mostra

Sempre aplicar estes 3, mesmo que não estejam escritos no prompt do usuário — são convenção fixa deste curso, usada em todo o gabarito testado:

1. **Tipo de nó no CML2**: `iol-xe` (roteador Cisco IOS-XE).
2. **`router-id` explícito** em cada roteador, igual ao IP da própria Loopback0.
3. **`passive-interface Loopback0`** — a loopback é anunciada no OSPF mas não forma adjacência por ela. Processo OSPF: `1`.

Sem esses 3 fatos o resultado ainda pode ser uma topologia funcional, mas não fica comparável ao gabarito testado deste repositório (`01-manual/respostas-configuracao/R{1..4}.txt`).

## Qual artefato gerar

Pergunte ao usuário (ou infira do contexto/pasta atual) qual dos 7 métodos ele quer, e leia o `references/` correspondente antes de gerar qualquer coisa — cada um traz o schema/API exato daquele método, gotchas conhecidos, e a ordem de limpeza correta:

| Método | Artefato | Referência |
|---|---|---|
| 1. Manual | Config CLI (texto pronto pra colar no console) | `references/01-manual.md` |
| 2. Bruno | Coleção `.bru` | `references/02-bruno.md` |
| 3. Linha de comando | Script bash+curl+jq **e/ou** PowerShell | `references/03-linha-de-comando.md` |
| 4. Python requests | Script Python usando `requests` | `references/04-python-requests.md` |
| 5. Python SDK | Script Python usando `virl2_client` | `references/05-python-sdk.md` |
| 6. Terraform | `main.tf`/`variables.tf`/`outputs.tf` (provider `CiscoDevNet/cml2`) | `references/06-terraform.md` |
| 7. MCP | Conversa ao vivo usando as ferramentas `mcp__cml2__*` (sem gerar arquivo) | `references/07-mcp.md` |

## Regras gerais

- Nunca hardcode IP/URL do controller ou credenciais — leia de variável de ambiente (`CML_URL`/`CML_USERNAME`/`CML_PASSWORD`, ou `TF_VAR_*` no caso do Terraform).
- O certificado do controller é autoassinado — cada referência explica a forma correta de ignorar a verificação SSL para aquela ferramenta específica (a forma certa varia: `session.verify = False` em Python, `-SkipCertificateCheck` em PowerShell 7+, `skip_verify = true` no provider Terraform, `NODE_TLS_REJECT_UNAUTHORIZED=0` só no bridge `mcp-remote`).
- Remoção de lab é sempre `stop` → `wipe` → `delete` (ou `terraform destroy`, que faz isso internamente) — pular o `wipe` dá erro 400.
- Se o usuário só anexou a imagem e pediu para "gerar o artefato da etapa N" sem mais contexto, não pergunte detalhes que já estão nos `references/` — gere direto.
