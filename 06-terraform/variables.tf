variable "cml_url" {
  description = "URL do controller CML2 (ex: https://172.22.50.230). Nunca hardcode aqui -- exporte via TF_VAR_cml_url a partir do .env (ver roteiro-terraform.md)."
  type        = string
}

variable "cml_username" {
  description = "Usuario do CML2."
  type        = string
}

variable "cml_password" {
  description = "Senha do CML2."
  type        = string
  sensitive   = true
}

variable "lab_title" {
  description = "Titulo do lab criado no CML2."
  type        = string
  default     = "teste-terraform"
}
