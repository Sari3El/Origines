# ALCS — DLL Setup Information

## Windows Dependencies (kb/103)
If you are a server host running a Windows server and someone wants to use the wOS DLL on it, install:
- https://www.microsoft.com/en-us/download/details.aspx?id=30679
- https://www.microsoft.com/en-us/download/details.aspx?id=52685

Download the right version: most likely the **x86** version for a 32-bit SRCDS instance, even on 64-bit Windows.
Optional but recommended: install Visual Studio to cover missing basic packages / service pack features.

## Rappel (kb/47, New DRM Info)
`lua/bin/gmsv_wos_crypt_win32.dll` (Windows) ou `lua/bin/gmsv_wos_crypt_linux.dll` (Linux) à la racine du serveur.
Sur ce serveur (Linux x86, 32 bits) : `gmsv_wos_crypt_linux.dll`.
