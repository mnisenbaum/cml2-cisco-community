output "lab_id" {
  description = "ID do lab criado no CML2."
  value       = cml2_lab.losango_ospf.id
}

output "node_ids" {
  description = "ID de cada roteador, por label."
  value       = { for label, node in cml2_node.router : label => node.id }
}

output "booted" {
  description = "true quando todos os nos terminaram de subir (BOOTED)."
  value       = cml2_lifecycle.start.booted
}
