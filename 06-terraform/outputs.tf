# outputs.tf -- Define as informações que serão exibidas na tela do console 
# após o 'terraform apply' concluir com sucesso.

output "lab_id" {
  description = "ID do lab criado no CML2."
  value       = cml2_lab.losango_ospf.id
}

output "node_ids" {
  description = "ID de cada roteador, por label."
  # Explicar para os alunos: Isto é um loop "for" em HCL (HashiCorp Configuration Language).
  # Ele varre todos os recursos do tipo "cml2_node.router" criados com o 'for_each' no main.tf,
  # montando um mapa de chaves/valores de Rótulo (label) para ID único (UUID) do CML2.
  value       = { for label, node in cml2_node.router : label => node.id }
}

output "booted" {
  description = "true quando todos os nos terminaram de subir (BOOTED)."
  value       = cml2_lifecycle.start.booted
}

