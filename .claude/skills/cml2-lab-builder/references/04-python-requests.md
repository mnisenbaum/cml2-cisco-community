# Método 4 — Python + requests

Artefato: script Python usando a biblioteca `requests` (sem SDK oficial).

## Estrutura recomendada

- `requests.Session()` autenticada uma vez (`POST /authenticate`), com `session.headers.update({"Authorization": f"Bearer {token}"})` — todas as chamadas seguintes reusam a sessão, sem repetir o header manualmente.
- `session.verify = False` (mais `urllib3.disable_warnings(...)` pra silenciar o aviso) — certificado autoassinado.
- `resp.raise_for_status()` em toda chamada — falha rápido em vez de continuar com dado incompleto.

## Sequência (mesmos endpoints do método 3)

1. `POST {base_url}/authenticate` → token.
2. (Checar duplicata) `GET {base_url}/labs?show_all=true&with_data=true`, filtrar por `lab_title`.
3. `POST {base_url}/labs` → `id`.
4. Por roteador: `POST {base_url}/labs/{lab_id}/nodes` com `params={"populate_interfaces": "true"}` e body `{"label":..., "node_definition":"iol-xe", "x":..., "y":..., "configuration": <texto>}`.
5. Por nó: `GET {base_url}/labs/{lab_id}/nodes/{node_id}/interfaces` com `params={"data":"true","operational":"false"}` → dict `{iface["label"]: iface["id"] for iface in resp.json()}`.
6. Por link: `POST {base_url}/labs/{lab_id}/links` com `{"src_int":..., "dst_int":...}`.
7. `PUT {base_url}/labs/{lab_id}/start`.
8. Loop de polling com `time.sleep` até `GET {base_url}/labs/{lab_id}/lab_element_state` mostrar todos `STARTED` (com deadline/timeout, não loop infinito).
9. Limpeza (idealmente um modo separado do script, ex. flag `--cleanup`): `PUT stop` → `PUT wipe` → `DELETE`, nessa ordem.

`.env`: ler `CML_URL`/`CML_USERNAME`/`CML_PASSWORD`, tratando `\r` residual e barra final de `CML_URL`.
