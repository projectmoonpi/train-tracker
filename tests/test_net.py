from train_tracker import net


def test_vm_names_from_maker_and_model():
    assert net.vm_name("VMware, Inc. VMware20,1") == "VMware"
    assert net.vm_name("innotek GmbH VirtualBox") == "VirtualBox"
    assert net.vm_name("Parallels International GmbH. Parallels ARM Virtual Machine") == "Parallels"
    assert net.vm_name("Microsoft Corporation Virtual Machine") == "Hyper-V"
    assert net.vm_name("Microsoft Corporation Surface Laptop 5") is None
    assert net.vm_name("Dell Inc. XPS 13 9310") is None


def test_vm_private_network_shapes():
    assert net.vm_private("VMware", "192.168.127.165", "192.168.127.2")        # NAT
    assert not net.vm_private("VMware", "192.168.68.50", "192.168.68.1")       # bridged onto the home network
    assert net.vm_private("VMware", "192.168.56.101", None)                    # host-only
    assert net.vm_private("VirtualBox", "10.0.2.15", "10.0.2.2")
    assert not net.vm_private("VirtualBox", "192.168.1.40", "192.168.1.1")
    assert net.vm_private("Parallels", "10.211.55.3", "10.211.55.1")
    assert net.vm_private("Hyper-V", "172.27.160.5", "172.27.160.1")
    assert not net.vm_private("a virtual machine", "192.168.1.40", "192.168.1.1")
