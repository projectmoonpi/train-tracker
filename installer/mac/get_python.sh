#!/bin/bash
# Python from python.org for Train Tracker, when the Mac hasn't got one that can run the installer's window (run by
# "Install Train Tracker.app"). Checked before it's installed: the expected file (its SHA-256), signed by the Python
# Software Foundation and accepted by macOS (notarized by Apple).
#   get_python.sh download        downloads the installer package, checks it, prints where it is
#   get_python.sh install <pkg>   installs it, then its certificates (run with administrator privileges)
#   get_python.sh version         the version it installs
# Designed and Created by Project Moon Pi.
PY_VERSION=3.14.10
PY_PKG=python-$PY_VERSION-macos11.pkg
PY_SHA256=286c7018aa2730f6747ca433dccdc2b31be45f078a9ea0ffa44d5f06368fd2d7
PY_SIGNER="Developer ID Installer: Python Software Foundation (BMM5U3QVKW)"
MM=${PY_VERSION%.*}
case "$1" in
download)
    dir=$(mktemp -d) || exit 1
    pkg="$dir/$PY_PKG"
    curl -fsSL -o "$pkg" "https://www.python.org/ftp/python/$PY_VERSION/$PY_PKG" ||
        { echo "Python couldn't be downloaded: check the internet connection." >&2; rm -rf "$dir"; exit 1; }
    [ "$(shasum -a 256 "$pkg" | cut -d' ' -f1)" = "$PY_SHA256" ] ||
        { echo "The Python download wasn't the expected file, so it wasn't installed." >&2; rm -rf "$dir"; exit 1; }
    pkgutil --check-signature "$pkg" | grep -qF "1. $PY_SIGNER" && spctl -a -t install "$pkg" 2>/dev/null ||
        { echo "The download isn't signed by the Python Software Foundation, so it wasn't installed." >&2; rm -rf "$dir"; exit 1; }
    echo "$pkg" ;;
install)
    /usr/sbin/installer -pkg "$2" -target / > /dev/null || exit 1
    # its certificates, so Python can check websites' HTTPS certificates
    "/Applications/Python $MM/Install Certificates.command" > /dev/null 2>&1 || true
    rm -rf "$(dirname "$2")" ;;
version)
    echo "$PY_VERSION" ;;
*)
    echo "usage: get_python.sh download | install <pkg> | version" >&2; exit 2 ;;
esac
