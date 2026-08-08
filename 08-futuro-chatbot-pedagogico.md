# Reflexão final — de digitar comando por comando a pedir a topologia em português

## O que os 7 métodos, em sequência, mostram

Este curso não foi desenhado como uma lista de "7 jeitos de fazer a mesma coisa" intercambiáveis. A ordem importa, e ela é deliberadamente uma rampa de abstração crescente:

1. **Manual** — o aluno digita cada comando no console, roteador por roteador. Entende o que cada linha de configuração faz porque é obrigado a escrevê-la.
2. **Bruno** — a mesma sequência de operações, agora como chamadas HTTP explícitas, uma por uma, visíveis e clicáveis. O aluno vê pela primeira vez que "criar um roteador" é, debaixo do capô, um `POST` com um corpo JSON.
3. **Linha de comando (bash/PowerShell)** — as mesmas chamadas, agora escritas como script. Ainda uma chamada de cada vez, mas expressas em texto que roda sozinho.
4. **Python + requests** — a mesma sequência, com uma linguagem de programação de verdade: variáveis, laços, tratamento de erro.
5. **SDK oficial** — a mesma sequência, mas o SDK esconde a mecânica HTTP: autenticação, sessão, polling de convergência viram uma chamada de método.
6. **Terraform** — muda de imperativo ("faça isso, depois isso") para declarativo ("eu quero este resultado final") — o aluno para de pensar em sequência de chamadas e passa a pensar em estado desejado.
7. **MCP** — o aluno para de escrever *qualquer* sequência. Descreve o resultado em linguagem natural, e é um assistente de IA quem decide quais operações chamar, em que ordem, com quais parâmetros — inclusive escolhendo, sozinho, uma ferramenta de mais alto nível (`create_full_lab_topology`) que nenhum dos métodos 1-6 tinha à disposição de forma tão direta.

O padrão: cada etapa esconde uma camada da anterior. E isso é o ponto pedagógico central deste curso — **a automação mais poderosa é também a que menos exige, e menos ensina, sobre o que está de fato acontecendo**. Um aluno que começasse direto na Etapa 7 conseguiria a mesma topologia funcionando, mas não saberia dizer o que é uma área OSPF, o que é uma interface `Loopback0`, ou por que existe uma ordem `stop → wipe → delete` para remover um lab. Começar pela Etapa 1 é o que torna a Etapa 7 compreensível, e não mágica.

## Fricções reais encontradas ao longo do curso — matéria-prima para um chatbot pedagógico

Cada etapa deste curso expôs pelo menos um obstáculo real, não hipotético, testado contra o controller de verdade:

- **Etapa 1**: nenhum, mas estabeleceu o gabarito que todas as outras etapas reusam.
- **Etapa 2 (Bruno)**: título de lab não é único no CML2 — rodar a criação duas vezes por engano gera um lab duplicado silenciosamente, sem erro.
- **Etapa 3 (linha de comando)**: `.env` salvo no Windows tem `\r` no fim de cada linha; `CML_URL` com barra final quebra a URL final (`//api/v0`); PowerShell 5.1 (o padrão do Windows) não tem `-SkipCertificateCheck`, precisa do PowerShell 7.
- **Etapa 4/5 (Python)**: o SDK oficial não atualiza sua cópia local das interfaces de um nó recém-criado até um `lab.sync()` explícito — chamar `get_interface_by_label` antes disso falha mesmo a interface existindo no servidor.
- **Etapa 5**: o estado real de um nó tem pelo menos dois níveis — `STARTED` (processo começou) e `BOOTED` (SO realmente terminou de subir) — e o critério "pronto" usado no polling manual das etapas 1-4 (`STARTED`) é mais fraco do que o que o SDK e o Terraform usam por padrão.
- **Etapa 6 (Terraform)**: remoção de lab exige `stop` → `wipe` → `delete`, nessa ordem exata — pular o `wipe` dá erro 400. E o provider identifica interfaces por número de slot (0, 1, 2...), não pelo nome (`Ethernet0/0`) nem pelo índice do YAML de exportação (`i1`, `i2`) — três numerações diferentes para a mesma coisa.
- **Etapa 7 (MCP)**: registrar o MCP como servidor HTTP direto falha por causa do certificado autoassinado do controller; funciona só com o bridge `mcp-remote`, que já vem pronto na configuração que o próprio CML2 devolve.

Nenhum desses obstáculos está documentado de forma óbvia e centralizada em nenhum lugar — cada um foi descoberto rodando o comando de verdade e lendo o erro real. É exatamente esse tipo de fricção, pequena mas acumulada, que consome a maior parte do tempo de quem está aprendendo a automatizar uma plataforma nova. Um chatbot pedagógico bem desenhado não substitui o aprendizado dessas fricções — ele muda **quando** e **como** o aluno lida com elas.

## O que um chatbot pedagógico poderia fazer diferente de um assistente de IA genérico

Um assistente de IA genérico (o "prompt sugerido para o chatbot" de cada roteiro deste curso) já ajuda o aluno a gerar um primeiro rascunho de script ou config. Mas ele não sabe, a priori, qual é o gabarito certo, não sabe em que etapa do curso o aluno está, e não tem acesso ao estado real do lab do aluno no CML2. Um chatbot pedagógico **desenhado para este curso especificamente** poderia:

- **Comparar contra o gabarito automaticamente**, em vez de o aluno adivinhar se o que o assistente genérico gerou está certo. Isso é tecnicamente trivial agora: a Etapa 7 já provou que um assistente com acesso ao MCP do CML2 consegue ler o estado real de um lab (`get_nodes_for_cml_lab`) e comparar configuração aplicada com texto esperado.
- **Segurar a resposta certa até o momento certo.** Nas etapas 1-3, o valor pedagógico está em o aluno errar e descobrir por quê (esquecer `no shutdown`, inverter `src_int`/`dst_int`, digitar a config no roteador errado). Um chatbot que corrige tudo de imediato, via MCP, elimina esse atrito — e com ele, parte do aprendizado. Faz sentido que o chatbot seja **mais generoso em automação nas etapas finais do curso e mais parcimonioso nas iniciais**, espelhando a progressão que este próprio curso já usa.
- **Explicar o erro relatado pela API, não só reportá-lo.** Um `400 Bad Request` do CML2 é, na maioria das vezes, um objeto JSON com uma mensagem técnica (como o `"Lab ... is not wiped, but in state STOPPED"` encontrado na Etapa 1). Um chatbot pedagógico pode traduzir isso para "essa etapa precisa passar por wipe antes de remover, é assim que o CML2 protege contra perda de dados de um lab ainda rodando" — o tipo de explicação que normalmente só vem de alguém que já bateu a cabeça nisso antes.
- **Adaptar o método ao momento do aluno, não ao módulo do curso.** Um aluno que já demonstrou entender OSPF manualmente (Etapa 1) mas está travado numa chamada de API mal formada (Etapa 4) não precisa de outra explicação de área 0 — precisa de ajuda com JSON. O chatbot genérico não faz essa distinção; um pedagógico, com contexto de progresso, faria.

## O risco de pular direto para o fim

A tentação óbvia, dado que a Etapa 7 já mostrou que dá para pedir a topologia inteira em uma frase, é usar só isso a partir de agora. É importante nomear o risco: um chatbot pedagógico que sempre resolve tudo via MCP ensina o aluno a **pedir**, não a **entender**. A automação mais poderosa deste curso só é segura de usar cedo se o aluno já souber, de cabeça, o que está sendo automatizado — senão vira uma caixa-preta que funciona até o dia em que não funciona, e ninguém no laboratório sabe por quê.

A ordem das 7 etapas deste curso é, também, uma resposta implícita a essa pergunta: comece pelo método mais manual, chegue ao mais automático por último, e só então confie nele.
