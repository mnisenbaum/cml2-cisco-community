#!/usr/bin/env python3
"""
Metodo 5 -- SDK oficial (virl2_client).

Este script demonstra a criação da topologia de referência usando o SDK oficial do CML2.

COMPARAÇÃO PEDAGÓGICA (Requests vs SDK):
- Nos métodos anteriores (Requests, Bash, Bruno), lidamos com a API REST crua: montagem manual 
  de payloads JSON, tratamento de cabeçalhos HTTP, gerenciamento de tokens JWT e criação 
  de loops de polling manuais para monitorar o status.
- Com o SDK oficial (`virl2_client`), subimos um nível de abstração. O código passa a ser 
  Orientado a Objetos. A biblioteca cuida automaticamente de:
    1. Autenticação e renovação silenciosa do token de sessão.
    2. Validação e limpeza da URL do controller.
    3. Mapeamento interno de UUIDs (conectamos portas usando objetos e nomes legíveis, 
       como "Ethernet0/0", em vez de IDs de 128 bits).
    4. Polling interno de convergência da topologia (esperando o estado real BOOTED e não apenas STARTED).

Uso:
    python3 cml_lab_sdk.py            # cria o lab de teste e aguarda convergencia
    python3 cml_lab_sdk.py --cleanup  # remove o lab de teste (stop -> wipe -> remove)

Lê CML_URL / CML_USERNAME / CML_PASSWORD de .env na raiz do repositorio.
"""
import argparse
import pathlib
import sys

from virl2_client import ClientLibrary

# Resolução de caminhos no sistema de arquivos local
REPO_ROOT = pathlib.Path(__file__).resolve().parents[1]
ENV_PATH = REPO_ROOT / ".env"
CONFIG_DIR = REPO_ROOT / "01-manual" / "respostas-configuracao"

LAB_TITLE = "teste-python-sdk"

# Definições canvas e conexões físicas da nossa topologia losango de referência
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
    # AUXILIAR: Lê o arquivo .env manualmente para carregar as credenciais.
    # Trata quebras de linha estilo Windows (\r) para evitar problemas de login.
    env = {}
    for line in path.read_text().splitlines():
        line = line.strip().rstrip("\r")
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        env[k.strip()] = v.strip().rstrip("\r")
    return env


def make_client():
    # ETAPA DE AUTENTICAÇÃO: O SDK cuida da sessão e do ciclo de vida dos tokens.
    env = load_env(ENV_PATH)
    
    # Explicar para os alunos: Diferente das chamadas cruas de Requests/Curl, 
    # o ClientLibrary do SDK limpa e valida a URL automaticamente, removendo barras extras.
    return ClientLibrary(
        url=env["CML_URL"],
        username=env["CML_USERNAME"],
        password=env["CML_PASSWORD"],
        ssl_verify=False,  # Ignora certificado autoassinado do controller CML2
    )


def create_lab():
    # FLUXO PRINCIPAL: Instanciação da topologia via Objetos Python.
    client = make_client()

    # Prevenção contra laboratórios duplicados usando método nativo de busca por título do SDK.
    if client.find_labs_by_title(LAB_TITLE):
        print(f"Ja existe um lab '{LAB_TITLE}'. Rode com --cleanup antes de recriar.", file=sys.stderr)
        sys.exit(1)

    # PASSO 1: Criar o contêiner do Laboratório. Retorna um objeto do tipo 'Lab'
    print(f"==> Criando lab '{LAB_TITLE}'...")
    lab = client.create_lab(
        title=LAB_TITLE,
        description="Lab de teste da Etapa 5 (Python SDK) -- remover apos confirmacao.",
    )
    print(f"    lab_id = {lab.id}")

    # PASSO 2: Instanciar os Roteadores (Nós) e injetar o arquivo de gabarito
    print("==> Criando os 4 nos (iol-xe) com as configs do gabarito...")
    nodes = {}
    for label, pos in NODES.items():
        # Lê a configuração Cisco IOS-XE de texto do gabarito correspondente
        config_text = (CONFIG_DIR / f"{label}.txt").read_text()
        
        # O método lab.create_node retorna um objeto do tipo 'Node'. 
        # Passamos a configuração direto nele e mantemos o populate_interfaces=True.
        nodes[label] = lab.create_node(
            label,
            "iol-xe",
            pos["x"],
            pos["y"],
            populate_interfaces=True,
            configuration=config_text,
        )
        print(f"    {label} -> node_id={nodes[label].id}")

    # PASSO 3: Sincronização Local (GOTCHA IMPORTANTE)
    # Explicar para os alunos: Embora 'populate_interfaces=True' crie as interfaces de hardware 
    # no servidor do CML2, o modelo de dados local na memória do Python não é atualizado imediatamente.
    # É fundamental chamar lab.sync() para buscar os detalhes do servidor antes de mapear links,
    # caso contrário o SDK não achará as portas físicas locais e dará erro de InterfaceNotFound.
    lab.sync()

    # PASSO 4: Criar conexões físicas (Links)
    print("==> Criando os 4 links do losango...")
    for node_a, if_a, node_b, if_b in LINKS:
        # Recupera os objetos de interface diretamente pelo nome amigável (rótulo)
        iface_a = nodes[node_a].get_interface_by_label(if_a)
        iface_b = nodes[node_b].get_interface_by_label(if_b)
        
        # Conecta as duas interfaces diretamente usando o método create_link do laboratório
        link = lab.create_link(iface_a, iface_b)
        print(f"    {node_a}:{if_a} <-> {node_b}:{if_b} -> link_id={link.id}")

    # PASSO 5 e 6: Inicialização e Polling de Convergência Robusto
    print("==> Iniciando o lab e aguardando convergencia (ate 300s)...")
    # Liga o laboratório (não travamos o start, pois usaremos a função específica de wait abaixo)
    lab.start(wait=False)
    
    # Explicar para os alunos: wait_until_lab_converged faz o polling de estado de forma nativa e robusta.
    # Diferente dos métodos anteriores que esperam o estado "STARTED" (a VM começou), o SDK monitora
    # se o nó atingiu o estado "BOOTED" (o SO do roteador terminou de subir de verdade).
    lab.wait_until_lab_converged(max_iterations=60, wait_time=5)
    
    # Atualiza as variáveis de estado local com o controller CML2
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
    # FLUXO DE DESTRUIÇÃO: Desliga, apaga o estado e remove o laboratório
    client = make_client()
    matches = client.find_labs_by_title(LAB_TITLE)
    if not matches:
        print(f"Nenhum lab '{LAB_TITLE}' encontrado.", file=sys.stderr)
        sys.exit(1)
    lab = matches[0]

    print(f"==> Removendo lab '{LAB_TITLE}' (id={lab.id})...")
    # Regra estrita do CML2 simplificada por métodos do SDK.
    # O SDK expõe funções com wait=True, travando a linha de execução até concluir a operação.
    
    # 1. Stop (Desliga)
    lab.stop(wait=True)
    print("    stop OK")
    
    # 2. Wipe (Apaga configurações de disco/NVRAM dos nós)
    lab.wipe(wait=True)
    print("    wipe OK")
    
    # 3. Remove (Exclui o lab do controller)
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
