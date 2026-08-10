# Método 2 — Bruno

Artefato: coleção Bruno (`.bru`), arquivos texto — `bruno.json` (metadados), `environments/<nome>.bru` (variáveis), e um `.bru` por requisição, numerados via `meta.seq` (essa é a ordem de execução real, não o nome do arquivo).

## Sequência de requisições

1. **Autenticar** — `POST {{base_url}}/authenticate` com body `{"username": "{{cml_username}}", "password": "{{cml_password}}"}`. Resposta é o JWT puro (string). Script `post-response`: `bru.setVar("token", res.body)`.
2. **Criar lab** — `POST {{base_url}}/labs` com `{"title": "{{lab_title}}", "description": "..."}`, header `Authorization: Bearer {{token}}`. `post-response`: `bru.setVar("lab_id", res.body.id)`.
3. **Criar cada nó** — `POST {{base_url}}/labs/{{lab_id}}/nodes?populate_interfaces=true` com `{"label": "R1", "node_definition": "iol-xe", "x": ..., "y": ..., "configuration": "<config completa>"}`. `post-response`: `bru.setVar("r1_id", res.body.id)` (um por nó).
4. **Ler interfaces de cada nó** — `GET {{base_url}}/labs/{{lab_id}}/nodes/{{r1_id}}/interfaces?data=true&operational=false`. Resposta é uma lista de objetos `{id, label}`. `post-response`: montar um dict `label → id` e salvar `bru.setVar("r1_eth00", ...)` / `bru.setVar("r1_eth01", ...)`.
5. **Criar cada link** — `POST {{base_url}}/labs/{{lab_id}}/links` com `{"src_int": "{{r1_eth00}}", "dst_int": "{{r2_eth00}}"}` (um por link do losango).
6. **Iniciar** — `PUT {{base_url}}/labs/{{lab_id}}/start` (espera `204`).
7. **Consultar estado** — `GET {{base_url}}/labs/{{lab_id}}/lab_element_state` — reexecutar até todos os nós aparecerem `STARTED`.
8. **Limpeza** — `PUT .../stop` → `PUT .../wipe` → `DELETE {{base_url}}/labs/{{lab_id}}`, nessa ordem exata (pular o wipe dá `400`).

## Ambiente

`environments/<nome>.bru`:
```
vars {
  base_url: https://SEU-CONTROLLER/api/v0
  cml_username: admin
  lab_title: teste-bruno
}

vars:secret [
  cml_password
]
```
Senha **sempre** como `vars:secret` — nunca em `vars {}` normal (isso vazaria a senha se a coleção for versionada).

## Padrão de encadeamento

Toda captura de valor usa `script:post-response { bru.setVar("nome", ...) }`; toda reutilização usa `{{nome}}` no request seguinte. Certificado autoassinado: a GUI do Bruno pede pra desativar verificação SSL da coleção nas Settings; a CLI (`bru run`) aceita `--insecure`.
