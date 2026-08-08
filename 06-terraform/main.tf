# Metodo 6 -- Terraform, provider oficial CiscoDevNet/cml2.
# Cria a topologia de referencia (losango OSPF, 4 roteadores iol-xe) de forma
# declarativa: lab -> nos (com config do gabarito) -> links -> lifecycle
# (inicia e espera todos os nos ficarem BOOTED).

terraform {
  required_providers {
    cml2 = {
      source  = "CiscoDevNet/cml2"
      version = "~> 0.9"
    }
  }
}

provider "cml2" {
  address     = var.cml_url
  username    = var.cml_username
  password    = var.cml_password
  skip_verify = true # certificado do controller e autoassinado
}

resource "cml2_lab" "losango_ospf" {
  title       = var.lab_title
  description = "Lab de teste da Etapa 6 (Terraform) -- destruir com terraform destroy apos confirmacao."
}

locals {
  nodes = {
    R1 = { x = -440, y = -120 }
    R2 = { x = -240, y = -320 }
    R3 = { x = -40, y = -120 }
    R4 = { x = -240, y = 80 }
  }
}

resource "cml2_node" "router" {
  for_each = local.nodes

  lab_id         = cml2_lab.losango_ospf.id
  label          = each.key
  nodedefinition = "iol-xe"
  x              = each.value.x
  y              = each.value.y
  # Gabarito de configuracao -- fonte unica de verdade em 01-manual/, os
  # outros metodos leem do mesmo lugar.
  configuration = file("${path.module}/../01-manual/respostas-configuracao/${each.key}.txt")
}

# Losango (anel de 4 elos): R1-R2, R2-R3, R3-R4, R4-R1.
# O provider identifica a interface por "slot" (numero), nao por UUID:
# slot 0 = Ethernet0/0, slot 1 = Ethernet0/1 (a Loopback0 nao tem slot).
resource "cml2_link" "r1_r2" {
  lab_id = cml2_lab.losango_ospf.id
  node_a = cml2_node.router["R1"].id
  slot_a = 0 # Ethernet0/0
  node_b = cml2_node.router["R2"].id
  slot_b = 0 # Ethernet0/0
}

resource "cml2_link" "r2_r3" {
  lab_id = cml2_lab.losango_ospf.id
  node_a = cml2_node.router["R2"].id
  slot_a = 1 # Ethernet0/1
  node_b = cml2_node.router["R3"].id
  slot_b = 1 # Ethernet0/1
}

resource "cml2_link" "r3_r4" {
  lab_id = cml2_lab.losango_ospf.id
  node_a = cml2_node.router["R3"].id
  slot_a = 0 # Ethernet0/0
  node_b = cml2_node.router["R4"].id
  slot_b = 0 # Ethernet0/0
}

resource "cml2_link" "r4_r1" {
  lab_id = cml2_lab.losango_ospf.id
  node_a = cml2_node.router["R4"].id
  slot_a = 1 # Ethernet0/1
  node_b = cml2_node.router["R1"].id
  slot_b = 1 # Ethernet0/1
}

# Recurso sintetico que "cola" lab+nos+links: inicia o lab e (com wait=true)
# so termina o apply quando todos os nos chegarem a BOOTED.
resource "cml2_lifecycle" "start" {
  lab_id = cml2_lab.losango_ospf.id
  state  = "STARTED"
  wait   = true

  depends_on = [
    cml2_link.r1_r2,
    cml2_link.r2_r3,
    cml2_link.r3_r4,
    cml2_link.r4_r1,
  ]
}
