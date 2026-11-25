#!/usr/bin/env python3
from pathlib import Path
import sys

lines = set(Path(sys.argv[1]).read_text().splitlines())
required = ['TARGET_ath79', 'TARGET_ath79_generic',
            'TARGET_ath79_generic_DEVICE_zbt_we826-q', 'PACKAGE_frpc',
            'PACKAGE_we826q-tailscale', 'PACKAGE_ppp', 'PACKAGE_chat',
            'PACKAGE_modemmanager', 'MODEMMANAGER_WITH_NETIFD',
            'PACKAGE_luci-light', 'PACKAGE_luci-proto-modemmanager',
            'PACKAGE_kmod-usb-serial-option', 'PACKAGE_kmod-tun',
            'PACKAGE_xz-utils', 'PACKAGE_xz',
            'PACKAGE_ca-bundle']
for key in required:
    if f'CONFIG_{key}=y' not in lines:
        sys.exit(f'REJECTED: defconfig dropped {key}')
for key in ['MODEMMANAGER_WITH_QMI', 'MODEMMANAGER_WITH_MBIM',
            'MODEMMANAGER_WITH_QRTR', 'PACKAGE_curl', 'PACKAGE_uqmi',
            'PACKAGE_luci-ssl', 'PACKAGE_luci-ssl-openssl', 'PACKAGE_tailscale']:
    if f'CONFIG_{key}=y' in lines or f'CONFIG_{key}=m' in lines:
        sys.exit(f'REJECTED: unwanted {key}')
print('defconfig package/profile gate passed; EXPERIMENTAL NOT FLASHED')
