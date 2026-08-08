#!/usr/bin/env python3
"""
Metodo 5 -- SDK oficial (virl2_client).

Cria a topologia de referencia (losango OSPF, 4 roteadores iol-xe) no CML2
usando o SDK oficial da Cisco (`virl2_client`, pip: `virl2_client`) em vez de
chamadas HTTP cruas. Mesmo resultado dos metodos anteriores (Bruno, bash,
PowerShell, Python requests), mas o SDK cuida de autenticacao, sessao HTTP e
polling de convergencia -- o script fica bem mais enxuto.

Uso:
    python3 cml_lab_sdk.py            # cria o lab de teste e aguarda convergencia
    python3 cml_lab_sdk.py --cleanup  # remove o lab de teste (stop -> wipe -> delete)

Le CML_URL / CML_USERNAME / CML_PASSWORD de .env na raiz do repositorio.
"""
import argparse
import pathlib
import sys

from virl2_client import ClientLibrary

REPO_ROOT = pathlib.Path(__file__).resolve().parents[1]
ENV_PATH = REPO_ROOT / ".env"
CONFIG_DIR = REPO_ROOT / "01-manual" / "respostas-configuracao"

LAB_TITLE = "teste-python-sdk"

NODES = {
    "R1": {"x": -440, "y": -120},
    "R2": {"x": -240, "y": -320},
    "R3": {"x": -40, "y": -120},
    "R4": {"x": -240, "y": 80},
}

LINKS = [
    ("R1", "Ethernet0/0", "R2", "Ethernet0/0"),
    ("R2", "Ethernet0/1", "R3", "Ethernet0/1"),
    ("R3", "Ethernet0/0", "R4", "Ethernet0/0"),
    ("R4", "Ethernet0/1", "R1", "Ethernet0/1"),
]


def load_env(path):
    # .env pode ter sido salvo com CRLF (editado no Windows) -- rstrip('\r') trata isso.
    env = {}
    for line in path.read_text().splitlines():
        line = line.strip().rstrip("\r")
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        env[k.strip()] = v.strip().rstrip("\r")
    return env


def make_client():
    env = load_env(ENV_PATH)
    # O proprio SDK trata barra final em CML_URL.
    return ClientLibrary(
        url=env["CML_URL"],
        username=env["CML_USERNAME"],
        password=env["CML_PASSWORD"],
        ssl_verify=False,  # certificado do controller e autoassinado
    )


def create_lab():
    client = make_client()

    if client.find_labs_by_title(LAB_TITLE):
        print(f"Ja existe um lab '{LAB_TITLE}'. Rode com --cleanup antes de recriar.", file=sys.stderr)
        sys.exit(1)

    print(f"==> Criando lab '{LAB_TITLE}'...")
    lab = client.create_lab(
        title=LAB_TITLE,
        description="Lab de teste da Etapa 5 (Python SDK) -- remover apos confirmacao.",
    )
    print(f"    lab_id = {lab.id}")

    print("==> Criando os 4 nos (iol-xe) com as configs do gabarito...")
    nodes = {}
    for label, pos in NODES.items():
        config_text = (CONFIG_DIR / f"{label}.txt").read_text()
        nodes[label] = lab.create_node(
            label,
            "iol-xe",
            pos["x"],
            pos["y"],
            populate_interfaces=True,
            configuration=config_text,
        )
        print(f"    {label} -> node_id={nodes[label].id}")

    # populate_interfaces=True cria as interfaces no servidor, mas o modelo local
    # do SDK so fica sabendo delas apos um sync explicito da topologia.
    lab.sync()

    print("==> Criando os 4 links do losango...")
    for node_a, if_a, node_b, if_b in LINKS:
        iface_a = nodes[node_a].get_interface_by_label(if_a)
        iface_b = nodes[node_b].get_interface_by_label(if_b)
        link = lab.create_link(iface_a, iface_b)
        print(f"    {node_a}:{if_a} <-> {node_b}:{if_b} -> link_id={link.id}")

    print("==> Iniciando o lab e aguardando convergencia (ate 300s)...")
    lab.start(wait=False)
    lab.wait_until_lab_converged(max_iterations=60, wait_time=5)
    lab.sync_states()
    for label, node in nodes.items():
        print(f"    {label}: {node.state}")

    print()
    print("=" * 60)
    print(f"Lab de teste '{LAB_TITLE}' criado e iniciado. lab_id = {lab.id}")
    print("Confira a convergencia OSPF pelo console/GUI do CML2:")
    print("  show ip ospf neighbor")
    print("  show ip route ospf")
    print(f"Depois, rode: python3 {pathlib.Path(__file__).name} --cleanup")
    print("=" * 60)


def cleanup():
    client = make_client()
    matches = client.find_labs_by_title(LAB_TITLE)
    if not matches:
        print(f"Nenhum lab '{LAB_TITLE}' encontrado.", file=sys.stderr)
        sys.exit(1)
    lab = matches[0]

    print(f"==> Removendo lab '{LAB_TITLE}' (id={lab.id})...")
    # O CML2 nao deixa remover um lab que nao passou por wipe -- precisa
    # ser nessa ordem: stop -> wipe -> remove. O SDK cuida do "delete" via .remove().
    lab.stop(wait=True)
    print("    stop OK")
    lab.wipe(wait=True)
    print("    wipe OK")
    lab.remove()
    print("    remove OK")
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
