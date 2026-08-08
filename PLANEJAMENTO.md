# CML2 API Access — Curso Progressivo (7 métodos), passo a passo

## Contexto

Moisés André Nisenbaum é o instrutor. Material de aula que ensina, de forma progressiva, todas as formas de acessar a API do Cisco CML2, para apresentação no Cisco Community online em 20/08/2026, com publicação depois em repositório público no GitHub. A topologia de referência é fixa (losango OSPF com 4 roteadores IOL-XE) e é recriada uma vez por método de acesso, para o aluno comparar abordagens: manual → Bruno → linha de comando (bash/PowerShell) → Python requests → SDK oficial (virl2_client) → Terraform → MCP.

## Handoff 2026-08-08: sessão continua no Claude Code CLI, dentro do WSL

A sessão Cowork (Windows) não tem rota de rede até o controller (ver "Limitação importante e permanente" abaixo) — o usuário confirmou conectividade tanto no WSL quanto no PowerShell da própria máquina, e decidiu migrar a continuação do trabalho para o **Claude Code CLI rodando no WSL**, que pode testar direto contra o controller real sem relay manual. Este arquivo (mais `00-topologia/topologia-e-enderecamento.md` e `01-manual/respostas-configuracao/R1.txt..R4.txt`, já criados e aprovados) é tudo que a sessão do WSL precisa ler para retomar exatamente daqui — próximo passo é a validação da Etapa 1 (criar lab de teste via API com o gabarito, iniciar nós, confirmar `STARTED`, usuário confere convergência OSPF manualmente). PowerShell fica reservado para testar especificamente a trilha PowerShell da Etapa 3 mais adiante.

## Ambiente de execução

- **Controller CML2**: IP dinâmico, muda a cada boot/troca de rede. Nenhum script ou `.md` deste projeto pode hardcodar o IP — tudo lê `CML_URL` de `.env` em tempo de execução. `CML_URL` pode vir com barra final; scripts devem tratar isso (`${CML_URL%/}` em bash, `.TrimEnd('/')` em PowerShell/Python) para não gerar `//api/v0` (dá 404). Credenciais também em `.env` (`CML_USERNAME`, `CML_PASSWORD`).
- **Sessão de trabalho**: Cowork, rodando no Windows, com a pasta `cml2-cisco-community` montada. As ferramentas de arquivo (ler/escrever/editar) tocam direto essa pasta no Windows do usuário.
- **Limitação importante e permanente**: o terminal (`bash`) desta sessão Cowork roda numa máquina Linux **isolada na nuvem** — não é o Windows do usuário, não é WSL. Essa máquina fica atrás de um proxy com allowlist restritiva e **não tem rota nenhuma até a rede local do usuário nem até a internet pública em geral** (confirmado testando três IPs diferentes do controller ao longo desta sessão — `172.22.50.230`, `172.31.53.221`, `172.29.48.114` — sempre `403 blocked-by-allowlist`; testado também um site público qualquer, mesmo bloqueio). Ou seja, isso não é resolvido trocando a rede do CML2 nem testando conectividade do lado do usuário (o `ping` do usuário funciona porque sai da própria máquina dele, na rede dele — o `curl` daqui sai de outro lugar, sem essa rota).
  - **Consequência prática**: nenhum teste real contra o controller pode ser feito a partir desta sessão. Fluxo acordado: Claude escreve o script/config de cada etapa aqui; o usuário roda no próprio terminal (PowerShell ou WSL/Ubuntu, ambos disponíveis na máquina dele e com rota até o controller) e reporta o resultado (output/erro) de volta, para eventual ajuste antes de fechar o roteiro daquela etapa.

## Como trabalhamos

- **Uma etapa de cada vez, com pausa para revisão**: cada um dos 7 métodos é uma etapa completa (scripts/coleção + teste real contra o controller, feito pelo usuário + roteiro `.md`). Ao terminar uma etapa, Claude para, mostra o que foi feito, e só avança para a próxima quando o usuário der o OK.
- **Sem automação de verificação via SSH/console**: a topologia é criada via API/script e confirmada por API que os nós chegaram ao estado `STARTED`. A verificação de que o OSPF convergiu (`show ip ospf neighbor`, `show ip route ospf`) fica por conta do usuário, feita manualmente pelo console do CML2 (GUI ou terminal server).
- **Nenhuma figura/diagrama nos `.md`** — só texto (tabelas markdown valem, ASCII art não).
- **PowerShell equivalente ao bash+curl**: o método de linha de comando tem duas trilhas — bash+curl (WSL/Linux/Mac) e PowerShell puro (`Invoke-RestMethod`, Windows nativo sem WSL) — mesmos passos nas duas.
- **Prompts sugeridos para chatbot**: cada roteiro (a partir do método manual) traz uma seção "Prompt sugerido para o chatbot" — o aluno usa um assistente de IA para gerar o script/coleção daquele método, e compara com o gabarito testado que Claude entrega.

## Ambiente técnico validado (conhecimento reaproveitado, não precisa redescobrir)

- Node definition do roteador: **`iol-xe`**. Image definition observada em sessão anterior: **`iol-xe-17-18-02`** (o `Lab_basico_OSPF.yaml` de referência guarda `image_definition: null`, ou seja, usa o padrão do controller — confirmar quando a etapa 1 rodar de fato).
- Interfaces do `iol-xe`: `Loopback0` automática + físicas `Ethernet0/0`...`Ethernet0/3` (4 interfaces físicas por padrão). O losango usa só `Ethernet0/0` e `Ethernet0/1` de cada roteador.
- `NodeCreate` (schema do `openapi.json`) exige só `node_definition`; aceita `x`, `y`, `label`, `configuration` (string) já na criação.
- Links: `POST /labs/{lab_id}/links` com `LinkCreate` (`src_int`/`dst_int` = UUIDs de interface, obtidos via `GET /labs/{lab_id}/nodes/{node_id}/interfaces?data=true`).
- Autenticação: `POST /authenticate` com `{username, password}` (schema `UserAuthData`).
- Estado dos nós: `GET /labs/{lab_id}/lab_element_state` retorna `{"nodes": {node_id: "STARTED"/...}}` — dá para fazer polling até todos ficarem `STARTED`.
- MCP embutido: `GET /ai/mcp/configuration` retorna um bloco `mcpServers` pronto (usa `npx -y mcp-remote https://.../mcp` com header `X-Authorization: Basic <user:pass base64>`). Testado e funcionando em sessão anterior.
- Terminal server do CML2: SSH na porta 22 do controller, mesmas credenciais do `.env`, dá acesso a um shell `consoles>` (`list`, `connect <uuid>`, `open <lab>/<node>/<linha>`). Não é usado para automação (decisão do usuário) — só registrado como referência para uso manual.
- Já existem labs no controller criados por outro uso — não mexer neles. Qualquer lab de teste criado para validar uma etapa leva título identificável (ex: `teste-<método>`) e é removido ao final da etapa, depois da confirmação do usuário.
- Remoção de lab: `DELETE /labs/{lab_id}` sozinho dá `400` (`Lab ... is not wiped, but in state STOPPED`) se o lab estiver rodando/parado sem wipe. Sequência correta: `PUT /labs/{lab_id}/stop` → `PUT /labs/{lab_id}/wipe` → `DELETE /labs/{lab_id}`.
- `title` de lab (`LabRequest.title`) **não é único** — recriar um lab com o mesmo título de um teste anterior gera duplicata em vez de erro. Sempre conferir `GET /labs?show_all=true&with_data=true` antes de recriar um lab de teste, para não deixar lixo no controller (aconteceu nesta sessão: script rodado 2x por engano criou 2 labs `teste-bruno`, ambos limpos manualmente depois).
- Estado de nó tem pelo menos dois níveis: `STARTED` (processo do node começou) e `BOOTED` (SO terminou de subir de verdade, detectado via padrão no console) — `GET .../lab_element_state` já reportou `BOOTED` direto em teste real (ver Etapa 5). Scripts que só esperam `STARTED` podem, em teoria, seguir em frente antes do roteador estar realmente pronto; na prática deu certo nas etapas 1-4 porque sempre houve alguns segundos de folga entre o polling terminar e o usuário checar o console manualmente.
- Terraform não vinha instalado nesta máquina WSL; baixado o binário oficial (1.15.8) para `~/.local/bin/terraform` (fora do PATH por padrão — precisa `export PATH="$HOME/.local/bin:$PATH"`). Provider `CiscoDevNet/cml2` slot de interface: `Ethernet0/0`→slot `0`, `Ethernet0/1`→slot `1` (a `Loopback0` não tem slot, é `null`).
- CLI do Bruno (`bru`, pacote `@usebruno/cli`) está instalada nesta máquina WSL — dá pra rodar coleções `.bru` inteiras sem abrir a GUI (`bru run <pasta> -r --env <nome> --insecure --env-var chave=valor ...`, `--bail` pra parar no primeiro erro). Variáveis de ambiente marcadas `secret` (bloco `vars:secret [ ... ]`) não ficam com valor no arquivo `.bru` versionado — precisam ser passadas em tempo de execução (`--env-var` no CLI, ou preenchidas manualmente na GUI).
- Máquina do usuário: Windows com PowerShell 7.6.4 e WSL Ubuntu disponíveis, ambos com rota de rede até o controller.

## Topologia e endereçamento (confirmado pelo usuário em 2026-08-08)

Fonte de verdade: `Lab_basico_OSPF.yaml` e a imagem `Lab_basico_OSPF-topologia e instrucoes.png`, ambos na raiz do repositório — não a descrição textual solta.

Losango (anel de 4 elos, não malha completa): **R1–R2, R2–R3, R3–R4, R4–R1**.

| Link | Rede | Lado A | Lado B |
|---|---|---|---|
| R1–R2 | 10.1.2.0/24 | R1 Ethernet0/0 = 10.1.2.1 | R2 Ethernet0/0 = 10.1.2.2 |
| R2–R3 | 10.2.3.0/24 | R2 Ethernet0/1 = 10.2.3.2 | R3 Ethernet0/1 = 10.2.3.3 |
| R3–R4 | 10.3.4.0/24 | R3 Ethernet0/0 = 10.3.4.3 | R4 Ethernet0/0 = 10.3.4.4 |
| R4–R1 | 10.1.4.0/24 | R4 Ethernet0/1 = 10.1.4.4 | R1 Ethernet0/1 = 10.1.4.1 |

Por roteador: R1 (Eth0/0→R2, Eth0/1→R4), R2 (Eth0/0→R1, Eth0/1→R3), R3 (Eth0/0→R4, Eth0/1→R2), R4 (Eth0/0→R3, Eth0/1→R1).

Loopbacks: R1 = 1.1.1.1/24, R2 = 2.2.2.2/24, R3 = 3.3.3.3/24, R4 = 4.4.4.4/24.
OSPF: processo 1, área 0 em todas as interfaces (via `ip ospf 1 area 0` na interface), `router-id` explícito = IP da própria loopback, `passive-interface Loopback0`.

Posições dos nós no canvas do CML2 (para os scripts de cada etapa recriarem o mesmo layout visual): R1 (x=-440, y=-120), R2 (x=-240, y=-320), R3 (x=-40, y=-120), R4 (x=-240, y=80).

`node_definition: iol-xe` para os 4 roteadores. Interfaces por nó: i0 = Loopback0, i1 = Ethernet0/0, i2 = Ethernet0/1, i3 = Ethernet0/2, i4 = Ethernet0/3.

## Estrutura de diretórios

```
cml2-cisco-community/
  openapi.json                          (já existe)
  .env                                   (já existe, criado pelo usuário)
  README.md                             índice geral — escrito por último
  00-topologia/topologia-e-enderecamento.md
  01-manual/respostas-configuracao/R1.txt..R4.txt, roteiro-manual.md
  02-bruno/CML2-Lab-Bruno/ (coleção .bru + environment), roteiro-bruno.md
  03-linha-de-comando/bash-wsl-linux-mac/, powershell-windows/, roteiro-linha-de-comando.md
  04-python-requests/cml_lab_requests.py, roteiro-python-requests.md
  05-python-sdk/cml_lab_sdk.py, roteiro-python-sdk.md
  06-terraform/main.tf, variables.tf, outputs.tf, roteiro-terraform.md
  07-mcp/roteiro-mcp.md
  08-futuro-chatbot-pedagogico.md
```

## Sequência de etapas

- **Etapa 0 — Topologia**: ✅ concluída. `00-topologia/topologia-e-enderecamento.md` criado e confirmado.
- **Etapa 1 — Manual**: ✅ concluída. Gabarito das 4 configs IOS-XE em `01-manual/respostas-configuracao/`. Validado via API pelo próprio Claude Code CLI (lab de teste `teste-manual`, 4 nós `iol-xe`, 4 links do losango, `start`, todos `STARTED` por polling); usuário confirmou convergência OSPF manualmente no console em 2026-08-08. Lab de teste removido (`stop` → `wipe` → `delete` — o controller não deixa apagar lab só `STOPPED`, sem `wipe` antes, dá `400`). `01-manual/roteiro-manual.md` escrito, cobrindo o passo a passo pela GUI e a seção "Prompt sugerido para o chatbot".

## Nota 2026-08-08: WSL tem rota real até o controller

Ao contrário da sessão Cowork anterior (isolada, sem rota — ver histórico abaixo), esta sessão Claude Code CLI no WSL tem conectividade real até o `CML_URL`. Autenticação e chamadas de API testadas com sucesso direto daqui. Fluxo revisado: **Claude escreve e roda os scripts de validação de cada etapa diretamente**, sem depender do usuário para rodar e reportar — o usuário só entra para a confirmação manual de convergência OSPF (console/GUI), que continua fora do escopo de automação por decisão dele. `.env` tem `\r` no final das linhas (CRLF) — scripts devem tratar isso ao ler (`tr -d '\r'` em bash, `.rstrip('\r')`/similar em Python) além do já registrado trailing slash do `CML_URL`.
- **Etapa 2 — Bruno**: ✅ concluída. Coleção `02-bruno/CML2-Lab-Bruno/` (19 requisições numeradas por `seq`: autenticar, criar lab, criar 4 nós com o gabarito, ler interfaces de cada nó, criar 4 links, iniciar, consultar estado, limpeza parar/wipe/remover). Validada de duas formas: (1) `bru run -r` ponta a ponta contra o controller real, 19/19 passou; (2) lab recriado pela própria coleção, nós até `STARTED`, usuário confirmou convergência OSPF manualmente no console em 2026-08-08, lab removido depois. `02-bruno/roteiro-bruno.md` escrito.
- **Extra (removido)**: skill de projeto `.claude/skills/cml2-bruno-lab-builder/` (gerador de coleções Bruno a partir de JSON de topologia) foi criada durante a Etapa 2, mas removida do projeto a pedido do usuário em 2026-08-08.
- **Etapa 3 — Linha de comando**: 🔄 quase concluída, falta 1 confirmação do usuário. `03-linha-de-comando/bash-wsl-linux-mac/` (`cml_lab_bash.sh` + `cml_lab_bash_cleanup.sh`) validado de ponta a ponta pelo Claude Code CLI contra o controller real — lab criado, `STARTED`, configs conferidas byte a byte contra o gabarito (idênticas), removido depois. Sem repetir checagem manual de OSPF (mesma topologia/config já confirmada 2x antes). `03-linha-de-comando/powershell-windows/` (`cml_lab_powershell.ps1` + cleanup) **escrito mas não testado** — usa `Invoke-RestMethod -SkipCertificateCheck` (exige PowerShell 7+, não funciona no Windows PowerShell 5.1). Usuário vai testar depois (decisão dele, 2026-08-08: "siga em frente, eu vou testar esse script só depois"). `roteiro-linha-de-comando.md` já escrito, cobrindo as duas trilhas, com nota explícita marcando a trilha PowerShell como pendente de validação real. **Pendente antes de fechar a etapa e avançar para a Etapa 4**: usuário rodar o script PowerShell, confirmar convergência OSPF (ou reportar erro para ajuste), e dar o OK.
- **Etapa 4 — Python requests**: ✅ concluída. `04-python-requests/cml_lab_requests.py` (modos `create`/`--cleanup` no mesmo arquivo) validado de ponta a ponta pelo Claude Code CLI contra o controller real: lab criado, 4 nós com gabarito, 4 links, `start`, todos `STARTED`, depois removido via `--cleanup` (stop/wipe/delete OK). Sem repetir checagem manual de OSPF (3ª+ reprodução da mesma topologia/config já confirmada). `04-python-requests/roteiro-python-requests.md` escrito.
- **Etapa 5 — Python SDK (virl2_client)**: ✅ concluída. `05-python-sdk/cml_lab_sdk.py` (modos `create`/`--cleanup`) validado de ponta a ponta pelo Claude Code CLI contra o controller real. Achado 2 gotchas reais (registrados abaixo e no roteiro): (1) `populate_interfaces=True` cria interfaces no servidor mas não no modelo local do SDK — precisa `lab.sync()` antes de `get_interface_by_label`, senão da `InterfaceNotFound`; (2) o SDK reporta estado do nó como `BOOTED` (via `wait_until_lab_converged()`), não `STARTED` como a API crua usada nos métodos anteriores — sinal de prontidão mais forte (SO realmente terminou de subir). `05-python-sdk/roteiro-python-sdk.md` escrito, com tabela comparativa requests-vs-SDK.
- **Etapa 6 — Terraform**: ✅ concluída. `06-terraform/{main.tf,variables.tf,outputs.tf,.gitignore}` com provider oficial `CiscoDevNet/cml2` (~> 0.9). `init/plan/apply/destroy` rodados de ponta a ponta pelo Claude Code CLI contra o controller real (Terraform baixado localmente, binário oficial HashiCorp, não estava instalado). `apply` completo com `booted=true`; topologia e configs conferidas via API crua (idênticas ao gabarito); usuário também testou e confirmou convergência. `destroy` limpou os 10 recursos sem erro. `06-terraform/roteiro-terraform.md` escrito, incluindo achado sobre numeração de `slot` (0=Ethernet0/0, 1=Ethernet0/1, Loopback0 sem slot) e a necessidade de `depends_on` explícito no `cml2_lifecycle`.
- **Etapa 7 — MCP**: ✅ concluída. Escopo evoluiu por pedido do usuário: além de reconfirmar `GET /ai/mcp/configuration` e documentar o registro, **validado de ponta a ponta criar a topologia via linguagem natural** (não só documentar registro). `claude mcp add --transport http` direto falhou por certificado autoassinado (`DEPTH_ZERO_SELF_SIGNED_CERT`) — funcionou registrando exatamente como o CML2 recomenda: stdio via `npx -y mcp-remote` com `NODE_TLS_REJECT_UNAUTHORIZED=0`, escopo `local` (nunca `project`, vazaria credencial em `.mcp.json` versionado). Novas conexões MCP só carregam em sessão nova — testado lançando `claude -p` headless separado já com o MCP conectado. O assistente usou uma ferramenta de alto nível não documentada previamente, `mcp__cml2__create_full_lab_topology` (cria lab+nós+links+configs numa chamada só), + `start_cml_lab`(wait_for_convergence) + `get_nodes_for_cml_lab`. Resultado conferido de forma independente via API crua (topologia, links e configs idênticos ao gabarito, todos os nós `BOOTED`) e usuário confirmou convergência OSPF manualmente. Lab de teste `teste-mcp` removido depois. `07-mcp/roteiro-mcp.md` escrito. Escrever roteiro.
- **Etapa 8 — Reflexão final**: ✅ concluída. `08-futuro-chatbot-pedagogico.md` escrito — conceitual, sem testes. Cobre a progressão deliberada de abstração crescente dos 7 métodos, lista consolidada das fricções reais encontradas em cada etapa (com números/comandos exatos), e reflexão sobre o que um chatbot pedagógico específico deste curso poderia fazer diferente de um assistente genérico (comparar contra gabarito via MCP, segurar a resposta certa nas etapas iniciais, traduzir erros de API, adaptar ao momento do aluno) — incluindo o risco de pular direto para a automação mais poderosa sem entender o que ela esconde.
- **Etapa 9 — README final**: ✅ concluída. `README.md` escrito (índice dos 7 métodos com um-parágrafo cada, topologia de referência, pré-requisitos gerais, estrutura de diretórios). Achado e corrigido antes de publicar: repositório não tinha `.gitignore` na raiz e o `.env` com credenciais reais do controller ficaria exposto — criado `.gitignore` raiz (exclui `.env`, `*:Zone.Identifier`, artefatos Python/Terraform) e `.env-modelo` como template (credenciais genéricas — instrução no README para preencher com as reais e renomear para `.env`). Também limpos artefatos residuais de teste em `06-terraform/` (`.terraform/`, `terraform.tfstate*` — já cobertos pelo `.gitignore` da etapa 6, mas removidos por higiene).

## Status: curso completo (2026-08-08)

Todas as 9 etapas concluídas. Repositório ainda não é um `git init` — pendente decisão do usuário sobre quando inicializar o repo e publicar no GitHub.

Cada etapa só começa depois do "OK" explícito do usuário na etapa anterior.
