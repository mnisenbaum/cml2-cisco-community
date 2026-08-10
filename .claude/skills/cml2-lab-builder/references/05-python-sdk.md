# Método 5 — Python SDK (virl2_client)

Artefato: script Python usando o SDK oficial `virl2_client` (`pip install virl2_client`).

## API do SDK

```python
from virl2_client import ClientLibrary

client = ClientLibrary(url=CML_URL, username=CML_USERNAME, password=CML_PASSWORD, ssl_verify=False)

lab = client.create_lab(title=..., description=...)

node = lab.create_node(label, "iol-xe", x, y, populate_interfaces=True, configuration=texto)
# node.id, node.state disponíveis depois

# GOTCHA: populate_interfaces=True cria as interfaces no servidor, mas o modelo
# local do SDK só fica sabendo delas depois de um lab.sync() explícito.
# Chamar get_interface_by_label antes disso lança InterfaceNotFound mesmo a
# interface existindo no controller.
lab.sync()

iface_a = node_a.get_interface_by_label("Ethernet0/0")
iface_b = node_b.get_interface_by_label("Ethernet0/0")
link = lab.create_link(iface_a, iface_b)

lab.start(wait=False)
lab.wait_until_lab_converged(max_iterations=60, wait_time=5)  # espera BOOTED, não só STARTED

lab.sync_states()
node.state  # "BOOTED" quando pronto de verdade (mais forte que "STARTED")
```

## Checagem de duplicata e limpeza

```python
client.find_labs_by_title(titulo)  # lista de Lab; usar pra checar antes de criar e pra achar na hora de limpar

lab.stop(wait=True)
lab.wipe(wait=True)
lab.remove()   # equivalente ao DELETE — precisa ser depois do wipe
```

`.env`: mesmo tratamento de CRLF/barra final que os outros métodos (o próprio SDK trata barra final de `url`).
