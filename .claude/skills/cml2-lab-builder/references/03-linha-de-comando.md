# Método 3 — Linha de comando (bash+curl+jq / PowerShell)

Artefato: um script (bash ou PowerShell) que roda a sequência de chamadas HTTP sozinho, sem cliente de API.

## Sequência de chamadas (igual nas duas trilhas)

1. `POST {base_url}/authenticate` com `{"username":..., "password":...}` → token JWT (resposta é a string pura).
2. (Opcional mas recomendado) `GET {base_url}/labs?show_all=true&with_data=true` com `Authorization: Bearer <token>` — checar se já existe lab com o mesmo título antes de criar (título de lab não é único no CML2).
3. `POST {base_url}/labs` com `{"title":..., "description":...}` → `id` do lab.
4. Para cada roteador: `POST {base_url}/labs/{lab_id}/nodes?populate_interfaces=true` com `{"label":..., "node_definition":"iol-xe", "x":..., "y":..., "configuration":"<texto completo>"}` → `id` do nó.
5. Para cada nó: `GET {base_url}/labs/{lab_id}/nodes/{node_id}/interfaces?data=true&operational=false` → lista `{id, label}`; extrair o `id` de `Ethernet0/0` e `Ethernet0/1`.
6. Para cada link do losango: `POST {base_url}/labs/{lab_id}/links` com `{"src_int":..., "dst_int":...}` (UUIDs de interface).
7. `PUT {base_url}/labs/{lab_id}/start` (espera `204`).
8. Polling: `GET {base_url}/labs/{lab_id}/lab_element_state` a cada alguns segundos até `nodes` todos `STARTED` (com timeout).
9. Limpeza: `PUT .../stop` → `PUT .../wipe` → `DELETE {base_url}/labs/{lab_id}`, nessa ordem.

## Gotchas por trilha

**bash**: usar `jq` pra montar o JSON da config com `--rawfile` (escapa `\n` corretamente — nunca concatenar string manualmente); `CML_URL` pode ter barra final (`${CML_URL%/}` antes de concatenar `/api/v0`); `.env` pode ter `\r` residual (`tr -d '\r'` ao ler); ignorar SSL com `curl -k`.

**PowerShell**: precisa do PowerShell **7+** (`Invoke-RestMethod -SkipCertificateCheck` não existe no Windows PowerShell 5.1 padrão); `ConvertTo-Json`/`ConvertFrom-Json` para o corpo; `.TrimEnd('/')` pra tratar barra final do `CML_URL`.
