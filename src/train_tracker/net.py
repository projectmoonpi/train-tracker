"""Network helpers: secure connections that work on any Python install, and this computer's network address."""
import socket
import ssl

import certifi


def ssl_context():
    """Certificates from certifi: python.org's Python for macOS has none until you run its "Install Certificates"
    step, which would make every feed fail."""
    return ssl.create_default_context(cafile=certifi.where())


def lan_address():
    """This computer's address on the local network (what a phone on the same Wi-Fi uses), or None."""
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
            s.connect(("192.0.2.1", 80))    # picks the outgoing interface; nothing is sent
            return s.getsockname()[0]
    except OSError:
        return None


# ---------- virtual machines ----------
# In a virtual machine on the VM program's own private network ("NAT", the usual default), phones on the Wi-Fi can't
# reach this computer's address, so the "Open on your phone" QR code can't work. Spot that, so the page can say so.

VM_VENDORS = (("vmware", "VMware"), ("parallels", "Parallels"), ("virtualbox", "VirtualBox"), ("innotek", "VirtualBox"),
              ("qemu", "QEMU"), ("kvm", "KVM"), ("xen", "Xen"))


def virtual_machine():
    """The virtual machine program this computer runs in ("VMware", "Hyper-V"...), or None on a real computer."""
    import sys
    text = ""
    try:
        if sys.platform == "win32":
            import winreg
            with winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE, r"HARDWARE\DESCRIPTION\System\BIOS") as k:
                text = " ".join(str(winreg.QueryValueEx(k, v)[0]) for v in ("SystemManufacturer", "SystemProductName"))
        elif sys.platform.startswith("linux"):
            text = " ".join(open(f"/sys/class/dmi/id/{f}").read() for f in ("sys_vendor", "product_name"))
        elif sys.platform == "darwin":
            import subprocess
            r = subprocess.run(["sysctl", "-n", "kern.hv_vmm_present"], capture_output=True, text=True, timeout=5)
            return "a virtual machine" if r.stdout.strip() == "1" else None
    except (OSError, ValueError, ImportError):
        return None
    return vm_name(text)


def vm_name(text):
    """The VM program named in a computer's maker and model text, or None."""
    low = text.lower()
    for key, name in VM_VENDORS:
        if key in low:
            return name
    if "microsoft corporation" in low and "virtual machine" in low:
        return "Hyper-V"
    return None


def default_gateway(ip):
    """The router this computer's address ip goes out through, or None."""
    import subprocess
    import sys
    try:
        if sys.platform == "win32":
            out = subprocess.run(["route", "print", "-4", "0.0.0.0"], capture_output=True, text=True, timeout=5,
                                 creationflags=0x08000000).stdout
            for line in out.splitlines():
                f = line.split()
                if len(f) >= 4 and f[0] == "0.0.0.0" and f[1] == "0.0.0.0" and f[3] == ip:
                    return f[2]
        elif sys.platform.startswith("linux"):
            for line in open("/proc/net/route").read().splitlines()[1:]:
                f = line.split()
                if len(f) > 2 and f[1] == "00000000":
                    g = int(f[2], 16)
                    return ".".join(str((g >> s) & 255) for s in (0, 8, 16, 24))
        elif sys.platform == "darwin":
            out = subprocess.run(["route", "-n", "get", "default"], capture_output=True, text=True, timeout=5).stdout
            for line in out.splitlines():
                if line.strip().startswith("gateway:"):
                    return line.split(":", 1)[1].strip()
    except (OSError, ValueError, subprocess.SubprocessError):
        pass
    return None


def vm_private(vm, ip, gateway):
    """Whether a VM's address looks like one on the VM program's own private network: VMware's NAT routes through
    .2, VirtualBox's (and QEMU's) is 10.0.2.x, Parallels' 10.211.55.x or 10.37.129.x, Hyper-V's Default Switch
    172.16-31.x. A VM bridged onto the home network looks like any other computer there."""
    import ipaddress
    try:
        a = ipaddress.ip_address(ip)
    except ValueError:
        return False
    if vm == "VMware":
        return gateway is None or gateway.endswith(".2")
    if vm in ("VirtualBox", "QEMU", "KVM"):
        return a in ipaddress.ip_network("10.0.2.0/24")
    if vm == "Parallels":
        return any(a in ipaddress.ip_network(n) for n in ("10.211.55.0/24", "10.37.129.0/24"))
    if vm == "Hyper-V":
        return a in ipaddress.ip_network("172.16.0.0/12")
    return False
