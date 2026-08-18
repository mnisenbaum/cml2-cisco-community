# variables.tf -- Declaração das variáveis de entrada do Terraform.
# Explicar para os alunos: Não colocamos valores sensíveis (como senhas ou IPs) hardcoded neste arquivo.
# O Terraform preenche essas variáveis automaticamente se exportarmos variáveis no terminal 
# com o prefixo "TF_VAR_" (ex: export TF_VAR_cml_url="...").

variable "cml_url" {
  description = "URL do controller CML2 (ex: https://172.22.50.230). Nunca coloque hardcode aqui -- exporte via TF_VAR_cml_url a partir do .env (ver roteiro-terraform.md)."
  type        = string
}

variable "cml_username" {
  description = "Usuario do CML2."
  type        = string
}

variable "cml_password" {
  description = "Senha do CML2."
  type        = string
  sensitive   = true # A flag 'sensitive' impede que o valor desta variável seja impresso em texto puro nos logs do console.
}

variable "lab_title" {
  description = "Titulo do lab criado no CML2."
  type        = string
  default     = "teste-terraform" # Valor padrão caso o usuário não forneça nenhum título.
}

