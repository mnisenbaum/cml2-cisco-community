# Método 3 — Linha de comando (bash+curl e PowerShell)

## Objetivo

Construir a mesma topologia de referência (ver [`00-topologia/topologia-e-enderecamento.md`](../00-topologia/topologia-e-enderecamento.md)) chamando a API REST do CML2 diretamente de um script de shell — sem cliente de API gráfico (Bruno) e sem SDK. Duas trilhas equivalentes, mesmos passos, mesma sequência de chamadas:

- **bash + curl + jq**: WSL, Linux ou macOS.
- **PowerShell 7+ (`Invoke-RestMethod`)**: Windows nativo, sem precisar de WSL.

Depois do método Bruno (requisição por requisição, clicando na GUI), este método mostra a mesma sequência de chamadas expressa como script imperativo — o próximo passo natural antes de ir para uma linguagem de programação de verdade (Python, na Etapa 4).

## Pré-requisitos

- **Trilha bash**: `curl` e `jq` instalados (ambos padrão na maioria das distros; no WSL Ubuntu, `sudo apt install jq` se faltar).
- **Trilha PowerShell**: PowerShell **7 ou superior** (`pwsh`). O parâmetro `-SkipCertificateCheck` do `Invoke-RestMethod`, usado para aceitar o certificado autoassinado do controller, só existe no PowerShell 7+ (não existe no Windows PowerShell 5.1 que vem por padrão no Windows). Confira sua versão com `$PSVersionTable.PSVersion` — se for a serie 5.x, instale o PowerShell 7 ([microsoft.com/powershell](https://learn.microsoft.com/powershell/scripting/install/installing-powershell)) ou use a trilha bash via WSL.

## Os scripts

| Arquivo | O que faz |
|---|---|
| [`bash-wsl-linux-mac/cml_lab_bash.sh`](bash-wsl-linux-mac/cml_lab_bash.sh) | Cria o lab, os 4 nós com o gabarito, os 4 links, inicia, faz polling até `STARTED` |
| [`bash-wsl-linux-mac/cml_lab_bash_cleanup.sh`](bash-wsl-linux-mac/cml_lab_bash_cleanup.sh) | Remove o lab de teste (`stop` → `wipe` → `delete`) |
| [`powershell-windows/cml_lab_powershell.ps1`](powershell-windows/cml_lab_powershell.ps1) | Equivalente ao script bash, em PowerShell |
| [`powershell-windows/cml_lab_powershell_cleanup.ps1`](powershell-windows/cml_lab_powershell_cleanup.ps1) | Equivalente ao cleanup, em PowerShell |

Ambos os scripts:

1. Leem `CML_URL`/`CML_USERNAME`/`CML_PASSWORD` de `.env` na raiz do repositório (nunca hardcodam o IP do controller).
2. Tratam barra final em `CML_URL` (`${CML_URL%/}` em bash, `.TrimEnd('/')` em PowerShell) para não gerar `//api/v0`.
3. Tratam `\r` residual no `.env` (arquivo pode ter sido salvo com CRLF no Windows).
4. Autenticam, checam se já existe um lab com o mesmo título (evita duplicata — ver nota da Etapa 2 sobre título de lab não ser único), criam o lab, os 4 nós `iol-xe` com a configuração do gabarito embutida, resolvem os UUIDs de interface de cada nó, criam os 4 links do losango, iniciam o lab e fazem polling do estado a cada 5s até todos os nós ficarem `STARTED` (timeout 300s).
5. **Não removem o lab ao final** — isso fica para o script de cleanup, depois da confirmação manual de convergência OSPF.

## Passo a passo

### Trilha bash

```bash
cd 03-linha-de-comando/bash-wsl-linux-mac
./cml_lab_bash.sh
```

Acompanhe a saída — cada etapa (autenticar, criar lab, criar nós, resolver interfaces, criar links, iniciar, polling) imprime seu progresso. Ao final, o script mostra o `lab_id` e pede para confirmar a convergência OSPF no console/GUI.

Confirme pelo console de qualquer roteador:

```
show ip ospf neighbor
show ip route ospf
```

Depois:

```bash
./cml_lab_bash_cleanup.sh
```

Para usar um título de lab diferente do padrão (`teste-cli-bash`), defina `LAB_TITLE` antes de rodar: `LAB_TITLE=meu-teste ./cml_lab_bash.sh`.

### Trilha PowerShell

```powershell
cd 03-linha-de-comando\powershell-windows
.\cml_lab_powershell.ps1
```

Mesmo fluxo: acompanhe a saída, confirme convergência OSPF no console/GUI, depois rode `.\cml_lab_powershell_cleanup.ps1`. Título customizável via `$env:LAB_TITLE = "meu-teste"` antes de rodar.

## Prompt sugerido para o chatbot

> Preciso de um script [bash com curl e jq / PowerShell 7 com Invoke-RestMethod] que automatize a criação de uma topologia no Cisco CML2 via API REST: 4 roteadores IOS-XE (R1-R4) ligados em anel, cada um com uma configuração IOS já pronta (texto multi-linha) que preciso enviar no corpo da requisição de criação do nó. A API: `POST /authenticate` com `{username, password}` retorna um JWT (usado como `Authorization: Bearer <token>` nas chamadas seguintes); `POST /labs` com `{title}` cria o lab e retorna `{id}`; `POST /labs/{lab_id}/nodes?populate_interfaces=true` com `{label, node_definition: "iol-xe", x, y, configuration}` cria cada nó; `GET /labs/{lab_id}/nodes/{node_id}/interfaces?data=true` retorna uma lista de `{id, label}` (preciso pegar o `id` de `Ethernet0/0` e `Ethernet0/1` de cada nó); `POST /labs/{lab_id}/links` com `{src_int, dst_int}` (UUIDs de interface) cria cada link; `PUT /labs/{lab_id}/start` inicia o lab; `GET /labs/{lab_id}/lab_element_state` retorna o estado de cada nó (preciso fazer polling até todos ficarem `STARTED`). O certificado do controller é autoassinado (preciso ignorar validação SSL). Gere o script completo, tratando erros de autenticação e timeout no polling.

Divergências comuns a comparar com o gabarito: escapar corretamente as quebras de linha da configuração dentro do JSON (usar `jq --rawfile`/`ConvertTo-Json`, não concatenação manual de string), ignorar certificado SSL do jeito certo para a versão do PowerShell instalada, e esquecer de tratar a barra final de `CML_URL`.

## Nota sobre a validação deste roteiro

- **Trilha bash**: validada de ponta a ponta pelo próprio Claude Code CLI contra o controller real — lab criado, iniciado, todos os nós confirmados `STARTED`. As 4 configurações aplicadas foram comparadas byte a byte com o gabarito de `01-manual/respostas-configuracao/` (idênticas), e a mesma topologia/config já teve a convergência OSPF confirmada manualmente duas vezes antes (Etapas 1 e 2) — por isso essa terceira reprodução não repetiu a checagem manual de convergência.
- **Trilha PowerShell**: escrita mas **ainda não testada** (esta sessão roda em WSL/Linux, sem `pwsh` disponível). Pendente: usuário rodar `cml_lab_powershell.ps1` no PowerShell 7 dele, confirmar convergência OSPF e reportar o resultado. Se algo divergir do esperado, este roteiro e o script serão ajustados antes de considerar a Etapa 3 encerrada.
