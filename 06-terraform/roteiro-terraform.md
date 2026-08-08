# Método 6 — Terraform

## Objetivo

Construir a mesma topologia de referência (ver [`00-topologia/topologia-e-enderecamento.md`](../00-topologia/topologia-e-enderecamento.md)) de forma **declarativa**, com o [provider oficial `CiscoDevNet/cml2`](https://registry.terraform.io/providers/CiscoDevNet/cml2/latest). Diferença fundamental em relação a todos os métodos anteriores (Bruno, bash, PowerShell, Python requests, Python SDK): até aqui, cada script descrevia uma **sequência de passos** ("faça isso, depois isso, depois isso"). Terraform descreve o **resultado desejado** — lab com estes nós, estes links, neste estado — e o provider decide a ordem das chamadas de API para chegar lá. Rodar `apply` de novo sem mudar nada não faz nada (idempotência); mudar um valor e rodar `apply` de novo só altera o que mudou.

## Pré-requisitos

- [Terraform](https://developer.hashicorp.com/terraform/install) instalado (`terraform version` para conferir).
- Nenhuma instalação adicional de provider — o `terraform init` baixa o `CiscoDevNet/cml2` automaticamente a partir do Terraform Registry.

## Os arquivos

| Arquivo | Conteúdo |
|---|---|
| [`variables.tf`](variables.tf) | Declaração das variáveis (`cml_url`, `cml_username`, `cml_password`, `lab_title`) — sem valores hardcoded, vêm de variáveis de ambiente `TF_VAR_*` |
| [`main.tf`](main.tf) | Provider, `cml2_lab`, 4× `cml2_node` (via `for_each`, config lida direto de `01-manual/respostas-configuracao/`), 4× `cml2_link`, e um `cml2_lifecycle` que inicia o lab e espera `BOOTED` |
| [`outputs.tf`](outputs.tf) | `lab_id`, `node_ids` (mapa label → UUID) e `booted` |
| `.gitignore` | Ignora `.terraform/`, `terraform.tfstate*` e `*.tfvars` — o state pode conter dados sensíveis e não deve ir para o git |

### Pontos que diferem dos métodos anteriores

- **Links usam `slot`, não UUID de interface.** O provider abstrai a resolução de UUID: `slot_a = 0` / `slot_b = 0` corresponde a `Ethernet0/0`, `slot = 1` a `Ethernet0/1` (a `Loopback0` não ocupa slot — confirmado consultando a API crua: `Ethernet0/0`→slot `0`, `Ethernet0/1`→slot `1`, `Ethernet0/2`→slot `2`, etc). Não precisa de um passo separado de "buscar interfaces" como nos métodos anteriores.
- **`cml2_lifecycle` é quem efetivamente liga o lab.** Criar os recursos `cml2_lab`/`cml2_node`/`cml2_link` só monta a topologia (equivalente a `DEFINED_ON_CORE`) — nada é iniciado até o recurso `cml2_lifecycle` com `state = "STARTED"`. Com `wait = true`, o `terraform apply` só termina quando todos os nós chegarem a `BOOTED` (não apenas `STARTED`) — o provider já faz esse polling internamente, igual ao `wait_until_lab_converged()` do SDK (Etapa 5).
- **`for_each` em vez de 4 blocos repetidos.** Os 4 roteadores vêm de um `local.nodes` (mapa label → x/y); o `cml2_node.router["R1"]`, `["R2"]` etc. dá pra referenciar cada um individualmente (usado nos links).

## Passo a passo

Exporte as credenciais do `.env` como variáveis de ambiente `TF_VAR_*` (Terraform lê `TF_VAR_<nome>` automaticamente para preencher `variable "<nome>"`):

```bash
cd 06-terraform
export TF_VAR_cml_url=$(grep '^CML_URL=' ../.env | cut -d= -f2- | tr -d '\r')
export TF_VAR_cml_username=$(grep '^CML_USERNAME=' ../.env | cut -d= -f2- | tr -d '\r')
export TF_VAR_cml_password=$(grep '^CML_PASSWORD=' ../.env | cut -d= -f2- | tr -d '\r')
```

```bash
terraform init    # baixa o provider CiscoDevNet/cml2
terraform plan    # mostra o que sera criado -- 10 recursos (1 lab + 4 nos + 4 links + 1 lifecycle)
terraform apply   # cria de fato -- pede confirmacao (digite "yes")
```

O `apply` fica "Still creating..." no `cml2_lifecycle.start` por dezenas de segundos — é o provider esperando os 4 roteadores chegarem a `BOOTED`. Ao final, os outputs mostram `booted = true` e o `lab_id`.

Confirme a convergência OSPF pelo console/GUI do CML2:

```
show ip ospf neighbor
show ip route ospf
```

Depois:

```bash
terraform destroy   # remove tudo -- pede confirmacao (digite "yes")
```

## Prompt sugerido para o chatbot

> Preciso de um projeto Terraform usando o provider `CiscoDevNet/cml2` (registry.terraform.io) para criar uma topologia no Cisco CML2: 4 roteadores IOS-XE (R1-R4) ligados em anel, cada um com uma configuração IOS já pronta. Recursos do provider: `cml2_lab` (título/descrição, retorna `id`); `cml2_node` (precisa de `lab_id`, `label`, `nodedefinition = "iol-xe"`, `x`/`y`, e opcionalmente `configuration` com o texto da config); `cml2_link` (precisa de `lab_id`, `node_a`, `node_b`, e opcionalmente `slot_a`/`slot_b` — slot 0 é a primeira interface física, slot 1 a segunda); `cml2_lifecycle` (recurso que efetivamente inicia o lab: `lab_id`, `state = "STARTED"`, `wait = true` para esperar todos os nós ficarem `BOOTED` antes do `apply` terminar — precisa de `depends_on` explícito nos links, já que ele não referencia os IDs deles diretamente). Quero usar `for_each` para os 4 nós em vez de repetir o bloco de recurso 4 vezes, e ler cada configuração de um arquivo texto separado com `file()`. Credenciais do provider (`address`, `username`, `password`) devem vir de variáveis (`TF_VAR_*`), nunca hardcoded. `skip_verify = true` no provider porque o certificado do controller é autoassinado.

Divergência comum a comparar com o gabarito: esquecer o `depends_on` no `cml2_lifecycle` (o Terraform pode tentar iniciar o lab antes dos links existirem, já que não há referência direta de atributo entre eles) ou confundir `slot` com o índice de interface do YAML de exportação do lab (`i1`, `i2`...) — são numerações diferentes.

## Nota sobre a validação deste roteiro

`terraform init` → `plan` → `apply` → `destroy` executados de ponta a ponta pelo próprio Claude Code CLI contra o controller real (Terraform instalado localmente para este teste, binário oficial da HashiCorp). `apply` completou com os 4 nós em `BOOTED` (`booted = true` no output) em ~41s. Conferido via API crua depois do apply: os 4 links ligam exatamente os pares e interfaces esperados do losango (`R1:Ethernet0/0↔R2:Ethernet0/0`, `R2:Ethernet0/1↔R3:Ethernet0/1`, `R3:Ethernet0/0↔R4:Ethernet0/0`, `R4:Ethernet0/1↔R1:Ethernet0/1`) e a configuração de cada nó é idêntica byte a byte ao gabarito. O usuário também testou e confirmou a topologia gerada. `terraform destroy` removeu os 10 recursos sem erro.
