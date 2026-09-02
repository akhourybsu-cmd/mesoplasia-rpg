# Phase J Private Server Hosting Guide

Phase J provides a private Windows/Linux dedicated server for trusted friends over LAN or direct IP. It does not provide matchmaking, relay/NAT traversal, account recovery, remote administration, or transport encryption. Do not reuse an important password as the server access code.

## 1. Prepare the private configuration

1. Copy `config/dedicated_server.example.json` to `config/dedicated_server.local.json`. The local file is ignored by Git.
2. Give every friend a unique, exact display label in `allowed_display_labels`.
3. Keep `allowlist_enabled` set to `true`.
4. Keep `listen_address` as `127.0.0.1` for same-PC testing. Change it to `0.0.0.0` only when accepting LAN or Internet connections.
5. Keep the default UDP port `24567`, or choose another port from `1024` through `65535`.
6. Never put the access code in the JSON file. The committed example names the `MESOPLASIA_SERVER_ACCESS_CODE` environment variable instead.

The server resolves `saves`, `backups`, and `logs` beneath the selected data root. For repository-local development, use the ignored `server-data/` directory. For a real host, prefer an operator-owned directory outside the project and install folders.

## 2. Set the secret for this terminal

In PowerShell, set the access code only for the current terminal session:

```powershell
$env:MESOPLASIA_SERVER_ACCESS_CODE = Read-Host "Private server access code"
```

Use at least eight characters. Close the terminal when hosting is finished to discard the process environment value.

## 3. Validate from the Godot development build

Replace the executable path if Godot is installed elsewhere:

```powershell
$godot = "C:\path\to\Godot_v4.7.2-stable_win64_console.exe"
& $godot --headless --path . res://scenes/server/DedicatedServer.tscn -- --server --config=res://config/dedicated_server.local.json --data-root=res://server-data --validate-and-stop
```

A successful validation prints `Mesoplasia dedicated server ready`, creates the instance directories, performs a validated shutdown backup, and exits with code `0`.

## 4. Export a server build

Install the matching official Godot 4.7 export templates first. The committed presets are `Windows Dedicated Server` and `Linux Dedicated Server`.

```powershell
& $godot --headless --path . --export-release "Windows Dedicated Server"
& $godot --headless --path . --export-release "Linux Dedicated Server"
```

Build output is ignored under `build/server/`. Dedicated exports use Godot's `dedicated_server` feature, boot directly into `DedicatedServer.tscn`, and strip visual resources from the server package.

## 5. Run and administer

Windows interactive console:

```powershell
& .\build\server\windows\MesoplasiaServer.console.exe -- --config="C:\MesoplasiaServer\server.json" --data-root="C:\MesoplasiaServer\data" --interactive-admin
```

Linux interactive console:

```bash
./build/server/linux/MesoplasiaServer.x86_64 -- --config=/srv/mesoplasia/server.json --data-root=/srv/mesoplasia/data --interactive-admin
```

The local console accepts:

| Command | Result |
| --- | --- |
| `status` | Redacted lifecycle, version, connection, and backup summary. |
| `players` | Authenticated peer and stable identity summary. |
| `save` | Validates all live durable records. |
| `backup` | Creates and rotates a validated manual backup. |
| `drain` | Stops new authentication while existing peers remain connected. |
| `kick <peer_id>` | Disconnects one current peer. |
| `shutdown` | Drains, validates saves, creates a shutdown backup, closes ENet, and exits. |

Use `shutdown` for normal stops. If required validation or backup fails, the server enters maintenance instead of reporting a clean stop.

## 6. Let a friend connect

For the Phase J gate, open `scenes/network/NetworkConnectionSandbox.tscn` in a Godot client checkout. Enter the host address, UDP port, shared access code, and an exact allowlisted display label, then select **Join**.

- Same computer: use `127.0.0.1`.
- Same LAN: use the host's private IPv4 address, commonly beginning with `192.168.` or `10.`.
- Internet/direct IP: use the host's public IP or DNS name.

For LAN/Internet hosting, allow the configured **UDP** port through the host firewall. Internet hosting usually also requires forwarding that UDP port on the router to the host computer's private address. Do not expose extra ports. Carrier-grade NAT, institutional networks, or double NAT may prevent direct hosting; Phase J has no relay fallback.

Example Windows firewall rule from an elevated PowerShell terminal:

```powershell
New-NetFirewallRule -DisplayName "Mesoplasia Private Server" -Direction Inbound -Protocol UDP -LocalPort 24567 -Action Allow
```

Remove or disable the rule when it is no longer needed.

## 7. Manual acceptance checklist

- The server starts with no graphical window and rejects a missing/short access code.
- An allowlisted client joins over loopback, then over LAN from a second computer.
- A non-allowlisted display label receives a generic authentication failure.
- `players`, `backup`, and `status` work without printing the raw access code.
- `drain` prevents a new client from authenticating.
- `shutdown` exits cleanly and creates a backup.
- Restarting with the same data root restores the same account/character identity.
- If testing direct Internet access, a friend outside the LAN can join through the forwarded UDP port.

Windows and Linux exports are configured, but each target still needs a manual smoke test on that operating system. Listen-server and solo production menus remain future integration work; Phase J preserves the existing local game path and uses the network sandbox for the client-side hosting gate.
