#!/usr/bin/env python3
"""
Metodo 4 -- Python + requests puro (sem SDK).

Cria a topologia de referencia (losango OSPF, 4 roteadores iol-xe) no CML2
via API REST, usando so a biblioteca `requests`. Mesma sequencia de chamadas
das etapas anteriores (Bruno, bash, PowerShell): autenticar, criar lab, criar
nos com config, resolver UUIDs de interface, criar links, iniciar, aguardar
STARTED.

Uso:
    python3 cml_lab_requests.py            # cria o lab de teste e aguarda STARTED
    python3 cml_lab_requests.py --cleanup  # remove o lab de teste (stop -> wipe -> delete)

Le CML_URL / CML_USERNAME / CML_PASSWORD de .env na raiz do repositorio.
"""
import argparse
import json
import pathlib
import sys
import time

import requests
import urllib3

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

REPO_ROOT = pathlib.Path(__file__).resolve().parents[1]
ENV_PATH = REPO_ROOT / ".env"
CONFIG_DIR = REPO_ROOT / "01-manual" / "respostas-configuracao"

LAB_TITLE = "teste-python-requests"

NODES = {
    "R1": {"x": -440, "y": -120},
    "R2": {"x": -240, "y": -320},
    "R3": {"x": -40, "y": -120},
    "R4": {"x": -240, "y": 80},
}

# (nodeA, ifaceA, nodeB, ifaceB)
LINKS = [
    ("R1", "Ethernet0/0", "R2", "Ethernet0/0"),
    ("R2", "Ethernet0/1", "R3", "Ethernet0/1"),
    ("R3", "Ethernet0/0", "R4", "Ethernet0/0"),
    ("R4", "Ethernet0/1", "R1", "Ethernet0/1"),
]


def load_env(path):
    # AUXILIAR: Lê o arquivo .env manualmente para carregar as credenciais.
    # Explicar para os alunos: .env editado no Windows pode conter caractere de retorno de carro (\r).
    # O rstrip('\r') remove esse caractere oculto que causaria erro de autenticação ou URL inválida.
    env = {}
    for line in path.read_text().splitlines():
        line = line.strip().rstrip("\r")
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        env[k.strip()] = v.strip().rstrip("\r")
    return env


def make_session():
    # ETAPA DE AUTENTICAÇÃO: Configura a sessão HTTP persistente com o token JWT.
    env = load_env(ENV_PATH)
    
    # Tratamento importante: Remove barra extra "/" no final do IP/URL para evitar URLs malformadas 
    # (ex: http://192.168.1.1//api/v0 resultaria em 404).
    base_url = env["CML_URL"].rstrip("/") + "/api/v0"

    session = requests.Session()
    # Desativa validação SSL (verificação de certificado) porque em laboratórios 
    # o certificado do controller CML2 quase sempre é autoassinado.
    session.verify = False  

    # Faz a requisição POST para obter o Token JWT
    resp = session.post(f"{base_url}/authenticate", json={
        "username": env["CML_USERNAME"],
        "password": env["CML_PASSWORD"],
    })
    resp.raise_for_status()
    token = resp.json()
    
    # Insere o Bearer Token no header padrão da sessão. 
    # A partir de agora, todas as chamadas usando 'session' já irão autenticadas.
    session.headers.update({"Authorization": f"Bearer {token}"})
    return session, base_url


def find_lab_id(session, base_url, title):
    # AUXILIAR: Busca no controller a lista de labs existentes e retorna o ID do lab que tenha o título buscado.
    # Explicar para os alunos: O CML2 identifica os recursos internamente por UUIDs, não pelo nome/título.
    resp = session.get(f"{base_url}/labs", params={"show_all": "true", "with_data": "true"})
    resp.raise_for_status()
    matches = [lab["id"] for lab in resp.json() if lab.get("lab_title") == title]
    return matches[0] if matches else None


def create_lab():
    # FLUXO PRINCIPAL: Criação e inicialização da topologia.
    session, base_url = make_session()

    # Prevenção: Evita duplicar labs com o mesmo título (o CML2 permite labs duplicados com títulos idênticos).
    if find_lab_id(session, base_url, LAB_TITLE):
        print(f"Ja existe um lab '{LAB_TITLE}'. Rode com --cleanup antes de recriar.", file=sys.stderr)
        sys.exit(1)

    # PASSO 1: Criar o contêiner do Laboratório
    print(f"==> Criando lab '{LAB_TITLE}'...")
    resp = session.post(f"{base_url}/labs", json={
        "title": LAB_TITLE,
        "description": "Lab de teste da Etapa 4 (Python requests) -- remover apos confirmacao.",
    })
    resp.raise_for_status()
    lab_id = resp.json()["id"]
    print(f"    lab_id = {lab_id}")

    # PASSO 2: Criar os Roteadores (Nós) e injetar suas configurações iniciais
    print("==> Criando os 4 nos (iol-xe) com as configs do gabarito...")
    node_ids = {}
    for label, pos in NODES.items():
        # Lê o arquivo txt de gabarito contendo o script de configuração Cisco IOS-XE (interface, IP, OSPF, etc.)
        config_text = (CONFIG_DIR / f"{label}.txt").read_text()
        
        # Cria o nó no CML2. O parâmetro populate_interfaces=true é CRÍTICO para que 
        # o CML crie automaticamente as interfaces físicas do modelo de hardware selecionado.
        resp = session.post(
            f"{base_url}/labs/{lab_id}/nodes",
            params={"populate_interfaces": "true"},
            json={
                "label": label,
                "node_definition": "iol-xe",
                "x": pos["x"],
                "y": pos["y"],
                "configuration": config_text,
            },
        )
        resp.raise_for_status()
        node_ids[label] = resp.json()["id"] # Guarda o UUID do nó recém-criado
        print(f"    {label} -> node_id={node_ids[label]}")

    # PASSO 3: Mapear as interfaces geradas (Necessário para a criação de links)
    # Explicar para os alunos: A API do CML2 não cria links dizendo "conecte R1:Eth0/0 a R2:Eth0/0". 
    # Ela exige o UUID interno da interface de origem e o UUID da de destino.
    print("==> Lendo interfaces de cada no para mapear nome -> UUID...")
    node_ifaces = {}
    for label, node_id in node_ids.items():
        resp = session.get(
            f"{base_url}/labs/{lab_id}/nodes/{node_id}/interfaces",
            params={"data": "true", "operational": "false"},
        )
        resp.raise_for_status()
        # Associa o nome amigável (ex: "Ethernet0/0") ao UUID correspondente retornado pela API
        node_ifaces[label] = {iface["label"]: iface["id"] for iface in resp.json()}
        print(f"    {label}: {sorted(node_ifaces[label].keys())}")

    # PASSO 4: Criar os cabos (Links) conectando os roteadores em formato de losango
    print("==> Criando os 4 links do losango...")
    for node_a, if_a, node_b, if_b in LINKS:
        # Envia os UUIDs mapeados no passo anterior para fechar o circuito físico
        resp = session.post(f"{base_url}/labs/{lab_id}/links", json={
            "src_int": node_ifaces[node_a][if_a],
            "dst_int": node_ifaces[node_b][if_b],
        })
        resp.raise_for_status()
        print(f"    {node_a}:{if_a} <-> {node_b}:{if_b} -> link_id={resp.json()['id']}")

    # PASSO 5: Ligar os equipamentos do laboratório
    print("==> Iniciando o lab...")
    resp = session.put(f"{base_url}/labs/{lab_id}/start")
    resp.raise_for_status()

    # PASSO 6: Acompanhar a inicialização (Polling)
    # Fica consultando o estado de inicialização dos nós a cada 5 segundos.
    # Explicar: STARTED indica que o processo de VM/contêiner iniciou no CML.
    print("==> Aguardando todos os nos ficarem STARTED (polling a cada 5s, timeout 300s)...")
    id_to_label = {v: k for k, v in node_ids.items()}
    deadline = time.time() + 300
    while time.time() < deadline:
        resp = session.get(f"{base_url}/labs/{lab_id}/lab_element_state")
        resp.raise_for_status()
        states = {id_to_label.get(nid, nid): st for nid, st in resp.json()["nodes"].items()}
        print(f"    {states}")
        
        # Quando todos mudarem para "STARTED", o loop encerra
        if all(st == "STARTED" for st in states.values()):
            print("==> Todos os nos estao STARTED.")
            break
        time.sleep(5)
    else:
        print("==> TIMEOUT esperando STARTED.", file=sys.stderr)
        sys.exit(2)

    print()
    print("=" * 60)
    print(f"Lab de teste '{LAB_TITLE}' criado e iniciado. lab_id = {lab_id}")
    print("Confira a convergencia OSPF pelo console/GUI do CML2:")
    print("  show ip ospf neighbor")
    print("  show ip route ospf")
    print(f"Depois, rode: python3 {pathlib.Path(__file__).name} --cleanup")
    print("=" * 60)


def cleanup():
    # FLUXO DE DESTRUIÇÃO: Para, apaga o estado e deleta o lab.
    session, base_url = make_session()
    lab_id = find_lab_id(session, base_url, LAB_TITLE)
    if not lab_id:
        print(f"Nenhum lab '{LAB_TITLE}' encontrado.", file=sys.stderr)
        sys.exit(1)

    print(f"==> Removendo lab '{LAB_TITLE}' (id={lab_id})...")
    # Regra do CML2: Não é permitido remover um lab cujo estado não tenha sido resetado ("wiped") antes.
    # A ordem estrita de desativação deve ser:
    # 1. Stop (desligar os nós) -> 2. Wipe (limpar configurações/discos) -> 3. Delete (excluir o lab).
    r = session.put(f"{base_url}/labs/{lab_id}/stop"); r.raise_for_status()
    print("    stop OK")
    r = session.put(f"{base_url}/labs/{lab_id}/wipe"); r.raise_for_status()
    print("    wipe OK")
    r = session.delete(f"{base_url}/labs/{lab_id}"); r.raise_for_status()
    print("    delete OK")
    print("==> Concluido.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cleanup", action="store_true", help="Remove o lab de teste em vez de criar")
    args = parser.parse_args()

    if args.cleanup:
        cleanup()
    else:
        create_lab()


if __name__ == "__main__":
    main()
