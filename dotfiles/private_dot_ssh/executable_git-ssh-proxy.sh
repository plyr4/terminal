#!/bin/bash
# renews transporter ssh certificates on demand, then proxies to github.com.
# referenced by a ProxyCommand in ~/.ssh/config.d/target.conf when enabled.

stdout() { echo "$@" >&2; }

if ! command -v transporter &>/dev/null; then
    stdout ""
    stdout "ERROR: transporter is not installed in \$PATH"
    stdout "Install from: http://go/transporter"
    stdout ""
    exit 1
fi

version="$(transporter version 2>&1 | awk '{ print $4 }')"

if ! ssh-add -L 2>/dev/null | grep -q ssh-ed25519-cert-v01@openssh.com; then
    stdout "SSH certificates are missing or expired!"
    stdout "Press Enter to renew certificates using transporter (${version})..."
    read </dev/tty
    transporter run -e stg

    if ! ssh-add -L 2>/dev/null | grep -q ssh-ed25519-cert-v01@openssh.com; then
        stdout ""
        stdout "ERROR: Failed to generate or add SSH certificate!"
        stdout "Please check transporter logs and try again."
        stdout ""
        exit 1
    fi

    stdout "certificate successfully generated and added to ssh agent"

    cert_key=$(ssh-add -L 2>/dev/null | grep ssh-ed25519-cert-v01@openssh.com)
    if [ -n "$cert_key" ]; then
        temp_cert=$(mktemp)
        echo "$cert_key" >"$temp_cert"
        expiry_info=$(ssh-keygen -L -f "$temp_cert" 2>/dev/null | grep "Valid:" | awk '{ print "Session is valid until " $5}')
        rm -f "$temp_cert"

        if [ -n "$expiry_info" ]; then
            stdout "$expiry_info"
        fi
    fi

    stdout "continuing..."
    stdout ""
fi

exec nc github.com 22
