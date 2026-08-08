# Método 1 — Manual (GUI do CML2)

## Objetivo

Construir a topologia de referência (losango OSPF com 4 roteadores IOL-XE, ver [`00-topologia/topologia-e-enderecamento.md`](../00-topologia/topologia-e-enderecamento.md)) inteiramente pela interface gráfica do CML2, configurando cada roteador manualmente pelo console. Este é o ponto de partida do curso: todo método seguinte (Bruno, linha de comando, Python, SDK, Terraform, MCP) automatiza uma parte deste mesmo processo — vale a pena sentir o trabalho manual antes de comparar.

Nenhum script ou chamada de API é usado neste método. É só GUI + console.

## Pré-requisitos

- Navegador com acesso ao controller CML2 (URL fornecida pelo instrutor/turma).
- Usuário e senha do CML2.
- A imagem `Lab_basico_OSPF-topologia e instrucoes.png` (raiz do repositório) aberta ao lado, como referência visual do layout.

## Passo 1 — Criar o lab

1. Faça login na GUI do CML2.
2. Clique em **New Lab** (ou equivalente na sua versão).
3. Dê um título identificável, por exemplo `manual-<seu-nome>`.

## Passo 2 — Adicionar os 4 roteadores

Para cada roteador (`R1`, `R2`, `R3`, `R4`):

1. Na paleta de nós, escolha a definição **`iol-xe`**.
2. Arraste para o canvas.
3. Renomeie o nó (clique no label) para `R1`, `R2`, `R3` ou `R4`.

Posicione os 4 nós no canvas seguindo aproximadamente o layout do losango da imagem de referência (não precisa ser pixel-perfeito — o importante é R1 embaixo à esquerda, R2 em cima, R3 embaixo à direita, R4 embaixo ao centro, formando o anel):

| Roteador | Posição aproximada |
|---|---|
| R1 | esquerda |
| R2 | topo |
| R3 | direita |
| R4 | base, entre R1 e R3 |

## Passo 3 — Conectar os links

Cada `iol-xe` vem com `Loopback0` automática e 4 interfaces físicas (`Ethernet0/0`–`Ethernet0/3`). Este lab usa só `Ethernet0/0` e `Ethernet0/1` de cada um. Arraste uma conexão de interface a interface para formar o anel (losango) — **não** é malha completa:

| Link | Lado A | Lado B |
|---|---|---|
| R1 ↔ R2 | R1 `Ethernet0/0` | R2 `Ethernet0/0` |
| R2 ↔ R3 | R2 `Ethernet0/1` | R3 `Ethernet0/1` |
| R3 ↔ R4 | R3 `Ethernet0/0` | R4 `Ethernet0/0` |
| R4 ↔ R1 | R4 `Ethernet0/1` | R1 `Ethernet0/1` |

Ao final, cada roteador tem exatamente 2 vizinhos (os links formam um anel fechado, não um X).

## Passo 4 — Iniciar os nós

1. Selecione os 4 nós (ou o lab inteiro).
2. Clique em **Start**.
3. Aguarde até os 4 nós ficarem com o indicador de estado **STARTED** (ícone verde). Roteadores IOL-XE costumam levar entre 30s e 2 minutos para ficarem prontos para console.

## Passo 5 — Configurar cada roteador pelo console

Abra o console de cada nó (clique com o botão direito no nó → **Console**, ou dê duplo-clique) e digite a configuração linha por linha (modo `configure terminal`). O gabarito completo de cada roteador está em [`respostas-configuracao/`](respostas-configuracao/):

- [`R1.txt`](respostas-configuracao/R1.txt)
- [`R2.txt`](respostas-configuracao/R2.txt)
- [`R3.txt`](respostas-configuracao/R3.txt)
- [`R4.txt`](respostas-configuracao/R4.txt)

Resumo do que cada gabarito faz (usando R1 como exemplo — os outros seguem o mesmo padrão trocando os IPs conforme a tabela de endereçamento):

```
hostname R1
no ip domain lookup
!
interface Loopback0
 ip address 1.1.1.1 255.255.255.0
 ip ospf 1 area 0
!
interface Ethernet0/0
 ip address 10.1.2.1 255.255.255.0
 no shutdown
 ip ospf 1 area 0
!
interface Ethernet0/1
 ip address 10.1.4.1 255.255.255.0
 no shutdown
 ip ospf 1 area 0
!
router ospf 1
 router-id 1.1.1.1
 passive-interface Loopback0
!
end
```

Pontos de atenção ao digitar:

- `no shutdown` é necessário nas físicas (a `Loopback0` já vem up por padrão).
- `ip ospf 1 area 0` na interface é o jeito mais direto de habilitar OSPF por interface (alternativa a `network` na seção `router ospf`).
- `router-id` explícito evita ambiguidade — sem ele, o IOS-XE escolhe automaticamente com base na maior loopback ou interface up, o que pode mudar dependendo da ordem em que as interfaces sobem.
- `passive-interface Loopback0` garante que a loopback é anunciada no OSPF mas não tenta formar vizinhança por ela (não faz sentido formar adjacência numa interface que não tem outro roteador do outro lado).

Repita para os 4 roteadores, cada um com seu próprio IP de loopback e das interfaces físicas (tabela completa em [`00-topologia/topologia-e-enderecamento.md`](../00-topologia/topologia-e-enderecamento.md)).

## Passo 6 — Salvar a configuração

Em cada roteador, depois de aplicar a config:

```
copy running-config startup-config
```

(ou `write memory`, equivalente). Sem isso, a configuração se perde se o nó for reiniciado.

## Passo 7 — Verificar a convergência OSPF

Em qualquer um dos 4 roteadores:

```
show ip ospf neighbor
```

Cada roteador deve enxergar exatamente 2 vizinhos (os dois roteadores adjacentes no anel), estado `FULL`.

```
show ip route ospf
```

Cada roteador deve ter, via OSPF, as rotas para as loopbacks e redes dos outros 3 roteadores que não estão diretamente conectados a ele.

Se algum vizinho não aparecer ou ficar preso em estado diferente de `FULL` (`INIT`, `2WAY`, `EXSTART`), revise a configuração da interface correspondente nos dois lados do link (IP/máscara, `no shutdown`, `ip ospf 1 area 0`).

## Prompt sugerido para o chatbot

Antes de olhar o gabarito, vale tentar gerar a configuração usando um assistente de IA e comparar o resultado. Um prompt possível:

> Preciso configurar 4 roteadores Cisco IOS-XE (R1, R2, R3, R4) ligados em anel (losango): R1–R2, R2–R3, R3–R4, R4–R1, sem malha completa. Cada link entre roteadores x e y (x<y) usa a rede 10.x.y.0/24, com o host final igual ao número do roteador (ex: link R2–R3 = 10.2.3.0/24, R2 fica com .2, R3 fica com .3). Cada roteador tem uma interface Loopback0 no formato x.x.x.x/24, onde x é o número do roteador (ex: Loopback0 de R4 = 4.4.4.4/24). Todos os roteadores rodam OSPF, processo 1, área 0, em todas as interfaces, com router-id explícito igual ao IP da própria loopback e a loopback como passive-interface. R1 usa Ethernet0/0 para R2 e Ethernet0/1 para R4; R2 usa Ethernet0/0 para R1 e Ethernet0/1 para R3; R3 usa Ethernet0/0 para R4 e Ethernet0/1 para R2; R4 usa Ethernet0/0 para R3 e Ethernet0/1 para R1. Gere a configuração completa dos 4 roteadores.

Compare a resposta do chatbot com o gabarito em [`respostas-configuracao/`](respostas-configuracao/) — divergências comuns costumam ser: `router-id` omitido ou incorreto, esquecer o `passive-interface`, ou trocar `network` por `ip ospf area` (ambos funcionam, mas o gabarito usa o segundo).

## Nota sobre a validação deste roteiro

A topologia e o gabarito de configuração acima foram validados via API (não pela GUI) antes deste roteiro ser escrito: um lab de teste `teste-manual` foi criado programaticamente com os mesmos 4 nós, mesmas configs e mesmos links, iniciado, e a convergência OSPF foi conferida manualmente no console pelo instrutor. O lab de teste foi removido depois da confirmação — os passos deste roteiro reproduzem o mesmo resultado, mas pela GUI, como um aluno faria.

## Limpeza

Ao terminar, se quiser liberar recursos do controller: selecione o lab, **Stop** os nós, depois **Wipe**, e por fim **Delete Lab**. O CML2 não permite apagar um lab que ainda esteja apenas parado (`STOPPED`) sem antes fazer o wipe.
