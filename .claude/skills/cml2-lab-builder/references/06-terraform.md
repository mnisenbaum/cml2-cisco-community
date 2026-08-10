# Método 6 — Terraform

Artefato: projeto Terraform (`main.tf`, `variables.tf`, `outputs.tf`) usando o provider oficial `CiscoDevNet/cml2` (registry.terraform.io, `~> 0.9`).

## Provider

```hcl
terraform {
  required_providers {
    cml2 = { source = "CiscoDevNet/cml2", version = "~> 0.9" }
  }
}

provider "cml2" {
  address     = var.cml_url       # https://..., de TF_VAR_cml_url
  username    = var.cml_username
  password    = var.cml_password  # variable sensitive = true
  skip_verify = true              # certificado autoassinado
}
```

Credenciais **sempre** via `variable` + `TF_VAR_*` de ambiente — nunca hardcoded no `.tf`.

## Recursos

- `cml2_lab` — `title`, `description`. Read-only: `id`.
- `cml2_node` — `lab_id`, `label`, `nodedefinition = "iol-xe"` (atenção: sem underscore, `nodedefinition`), `x`, `y`, `configuration` (texto da config completa). Usar `for_each` sobre um `local` map dos 4 roteadores em vez de repetir o bloco.
- `cml2_link` — `lab_id`, `node_a`, `node_b`, e opcionalmente `slot_a`/`slot_b`. **Slot, não UUID de interface**: slot `0` = `Ethernet0/0`, slot `1` = `Ethernet0/1` (a `Loopback0` não ocupa slot).
- `cml2_lifecycle` — recurso síntetico que efetivamente inicia o lab: `lab_id`, `state = "STARTED"`, `wait = true` (só termina o apply quando todos os nós chegarem a `BOOTED`). **Precisa de `depends_on` explícito** listando todos os `cml2_link`, já que não referencia os IDs deles diretamente.

## Config de cada nó

```hcl
configuration = file("${path.module}/<caminho para o arquivo de config de cada roteador>")
```
(ou string inline, se a config for gerada dinamicamente).

## Outputs úteis

`cml2_lab.x.id`, `{ for k, n in cml2_node.router : k => n.id }`, `cml2_lifecycle.start.booted`.

## Limpeza

`terraform destroy` (cuida de stop/wipe/delete internamente via o provider).
