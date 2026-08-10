# Método 1 — Manual (config CLI)

Artefato: texto de configuração CLI, pronto para colar no console de cada roteador em `configure terminal` (ou digitar linha por linha). Não é um script — não há API envolvida, o método é literalmente digitar no console do CML2.

## Formato esperado (ordem usada no gabarito testado)

Para cada roteador `Rn` (n = 1..4):

```
hostname Rn
no ip domain lookup
!
interface Loopback0
 ip address n.n.n.n 255.255.255.0
 ip ospf 1 area 0
!
interface Ethernet0/0
 ip address <IP do link em Ethernet0/0> 255.255.255.0
 no shutdown
 ip ospf 1 area 0
!
interface Ethernet0/1
 ip address <IP do link em Ethernet0/1> 255.255.255.0
 no shutdown
 ip ospf 1 area 0
!
router ospf 1
 router-id n.n.n.n
 passive-interface Loopback0
!
end
```

- `no shutdown` é necessário nas físicas (a `Loopback0` já vem up por padrão).
- `ip ospf 1 area 0` na interface é a forma direta de habilitar OSPF por interface (alternativa ao `network` dentro de `router ospf`).
- Gerar as 4 configs completas, uma por roteador, cada uma com seus próprios IPs (ver regras de endereçamento no `SKILL.md`).
