# Metodo 6 -- Terraform, usando o provider oficial CiscoDevNet/cml2.
#
# COMPARAÇÃO PEDAGÓGICA (Declarativo vs Imperativo):
# Nos métodos de scripts (Requests, SDK, Bash), tivemos que especificar a ordem exata dos passos:
# 1. Cria o Lab -> 2. Cria Nós -> 3. Mapeia UUIDs -> 4. Conecta Links -> 5. Inicia.
# Com o Terraform, declaramos os RECURSOS desejados e suas relações (como links conectando nós).
# O Terraform calcula a árvore de dependências e decide o que criar, na ordem certa.

# Configuração dos Providers necessários para este módulo Terraform
terraform {
  required_providers {
    cml2 = {
      source  = "CiscoDevNet/cml2"
      version = "~> 0.9" # Limita a versão para evitar mudanças que quebrem compatibilidade
    }
  }
}

# Definição e autenticação do Provider CML2
provider "cml2" {
  address     = var.cml_url
  username    = var.cml_username
  password    = var.cml_password
  skip_verify = true # Ignora aviso de certificado autoassinado (comum em servidores de laboratório)
}

# Recurso: Cria o contêiner do Laboratório no CML2
resource "cml2_lab" "losango_ospf" {
  title       = var.lab_title
  description = "Lab de teste da Etapa 6 (Terraform) -- destruir com terraform destroy apos confirmacao."
}

# Locals: Variáveis locais para estruturar dados internos do Terraform de forma limpa.
# Definimos o nome de cada roteador e suas respectivas coordenadas x e y no canvas do CML2.
locals {
  nodes = {
    R1 = { x = -440, y = -120 }
    R2 = { x = -240, y = -320 }
    R3 = { x = -40, y = -120 }
    R4 = { x = -240, y = 80 }
  }
}

# Recurso: Cria os Roteadores (Nós)
# Explicar para os alunos o uso de 'for_each': Em vez de escrever 4 blocos "cml2_node" repetidos,
# usamos o 'for_each' iterando sobre o mapa 'local.nodes'. Isso cria 4 recursos independentes 
# que podem ser acessados via cml2_node.router["R1"], ["R2"], etc.
resource "cml2_node" "router" {
  for_each = local.nodes

  lab_id         = cml2_lab.losango_ospf.id # Associa o roteador ao lab criado acima
  label          = each.key                 # R1, R2, R3, R4
  nodedefinition = "iol-xe"                 # Tipo do nó do roteador no CML2
  x              = each.value.x
  y              = each.value.y
  
  # Gabarito de configuração: Lê diretamente o arquivo txt do repositório correspondente a cada roteador
  # usando a função file() do Terraform.
  configuration = file("${path.module}/../01-manual/respostas-configuracao/${each.key}.txt")
}

# Recurso: Conexões Físicas (Links)
# Losango (anel de 4 elos): R1-R2, R2-R3, R3-R4, R4-R1.
# 
# PONTO PEDAGÓGICO CRÍTICO:
# O CML2 expõe UUIDs de interface geradas aleatoriamente, mas o Provider do Terraform abstrai isso
# utilizando um conceito de "slots" (índices numéricos de porta).
# No modelo de hardware iol-xe:
# - slot 0 corresponde à porta física Ethernet0/0.
# - slot 1 corresponde à porta física Ethernet0/1.
# (A porta Loopback0 não ocupa slot, pois é uma interface lógica criada via software).
# Não precisamos rodar um "mapeador de UUIDs" como nos scripts manuais!

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

# Recurso: Ciclo de vida e Inicialização
# No Terraform, a simples criação dos nós e links não os liga (eles ficam no estado DEFINED/STOPPED).
# Criamos o recurso 'cml2_lifecycle' para iniciar o laboratório ('state = "STARTED"').
# O parâmetro 'wait = true' trava o comando 'terraform apply' até que todos os nós estejam no estado BOOTED 
# (ou seja, o provider faz o polling internamente por nós).
#
# IMPORTANTE: O bloco 'depends_on' garante que o laboratório só será ligado DEPOIS que todos os 4 links 
# forem conectados física e logicamente.
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

