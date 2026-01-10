# vault.deadlight

A local credential store for CLI tools and proxies in the Deadlight ecosystem. Stores encrypted credentials offline and injects them into commands or requests on demand.

Part of the Deadlight suite: reuses crypto primitives from lib.deadlight (PBKDF2-SHA256 for key derivation) and adds ChaCha20-Poly1305 for encryption. Designed for intermittent or offline environments, like those in proxy.deadlight or meshtastic.deadlight workflows.

## Purpose

Handles credential management for terminals and proxies where browser tools don't apply. Focuses on SSH, API tokens, and similar in constrained setups.

Example workflows:

| Scenario | Without vault | With vault |
|----------|---------------|------------|
| SSH to multiple servers on borrowed device | Enter passwords or set up keys each time | Unlock once; auto-inject via agent |
| Curl API over flaky link | Paste token; retry on drops | Inject from store; works offline |
| Proxy auth for internal services | Manual headers in tools | Socket-based injection; transparent |
| Device failover, no net | Re-enter all creds | Export/import encrypted DB via USB |

Not a full password manager replacement—targets CLI/proxy gaps only.

## Ecosystem Integration

Extends proxy.deadlight with credential injection. Standalone for CLI, but integrates via Unix socket.

```
Deadlight Stack:

vault.deadlight (CLI auth/store) --inject creds--> proxy.deadlight (SOCKS/HTTP gateway)
                                       |
                                       | (reuses PBKDF2, adds ChaCha20)
                                       v
lib.deadlight (crypto utils)
```

## Quick Start

Build (zero deps beyond lib.deadlight):

```bash
git clone https://github.com/gnarzilla/vault.deadlight
cd vault.deadlight
make  # Links against lib.deadlight
```

Init and add:

```bash
./deadlight_vault init  # Sets master password, creates ~/.deadlight/vault.db
./deadlight_vault add github-api --type token --value ghp_xxxxxxxx
```

Use:

```bash
./deadlight_vault exec github-api -- curl -H "Authorization: Bearer {TOKEN}" https://api.github.com/user
```

## How It Works

- Key from master password via PBKDF2-SHA256 (from lib.deadlight/crypto.h).
- Encrypt creds with ChaCha20-Poly1305 (~300 LOC public domain impl).
- Decrypt ephemerally (<100ms in memory), then secure_zero (from lib.deadlight/crypto.h).

Code snippet:

```c
// Derive key
pbkdf2_sha256(master_password, salt, 100000, derived_key);

// Encrypt
chacha20_poly1305_encrypt(plaintext, derived_key, nonce, encrypted);

// Decrypt and wipe
chacha20_poly1305_decrypt(encrypted, derived_key, nonce, plaintext);
secure_zero(plaintext, length);
```

DB schema (SQLite):

```sql
CREATE TABLE vault_meta (version INTEGER, salt BLOB, created_at INTEGER);
CREATE TABLE credentials (
    id INTEGER PRIMARY KEY,
    name TEXT UNIQUE,
    type TEXT,  -- token/password/ssh_key
    encrypted_value BLOB,
    nonce BLOB,
    metadata TEXT,  -- JSON e.g. {"expires": "..."}
    created_at INTEGER,
    last_used INTEGER
);
```

Typical size: ~40KB for 50 creds.

## Features

- Local encryption/decryption.
- Inject into CLI cmds via `exec`.
- SSH agent support for key loading.
- Proxy socket for request injection.
- Export/import encrypted DBs offline.
- Constant-time compares, secure wipes.

Limitations:

- No browser/GUI/cloud sync/2FA.
- Single-user per system.
- CLI-only.

## Commands

```bash
vault init  # Create vault
vault add <name> --type <type> --value <val> [--file <path>]  # Add cred
vault list  # List names
vault exec <name> -- <cmd>  # Inject into cmd
vault export --output <file>  # Encrypted dump
vault import <file>  # Load dump
vault unlock/lock  # Manage key in mem
vault delete <name>  # Remove cred
```

## Proxy Setup

Enable socket:

```bash
vault config set proxy.enabled true
vault config set proxy.socket /var/run/deadlight_vault.sock
```

Proxy connects on start. Match creds to domains:

```bash
vault add github-api --proxy-match "api.github.com"
```

Flow: Client → proxy → vault (decrypt/inject) → remote.

## Use Cases

- DevOps: Auto-SSH over satellite: `vault unlock; for host in hosts.txt; do ssh ubuntu@$host ...; done`
- API testing: `vault exec stripe-test -- curl https://api.stripe.com -H "Authorization: Bearer {TOKEN}"`
- Failover: Export DB to USB, import on backup device.
- Proxied access: Set HTTP_PROXY, curl internal API—vault injects auth.

## Roadmap

Q1 2026 (MVP):

- [x] PBKDF2 reuse from lib.deadlight.
- [x] ChaCha20-Poly1305 impl.
- [x] SQLite store, basic cmds (init/add/list/exec).
- [ ] SSH agent.
- [ ] Proxy socket.

Post-MVP:

- Env var injection.
- Expiry warnings.
- Audit log (opt-in).

Out of scope: GUI, cloud, Windows native, 2FA.

## Security

Threats addressed:

- DB theft: Strong encryption.
- Memory: Ephemeral decrypts, wipes.
- Tampering: Poly1305 MAC.
- Timing: Constant-time compares (from lib.deadlight).

Not addressed:

- Compromised OS/root.
- Weak master pw (enforcement TBD).
- Unlocked vault.
- Physical attacks (use FDE).

No cloud sync: Avoids net deps, third-party trust. Use manual exports.

Audit: Crypto from public domain/ref impls. ~800 LOC custom. Not pro-audited; use cautiously.

## Build

Prereqs: build-essential (Debian), etc. Links lib.deadlight.

```bash
make  # ~180KB binary
make test  # Crypto/memory checks
```

Cross: `make CC=aarch64-linux-gnu-gcc` for ARM.

## FAQ

- Vs. pass/gopass: Focuses on auto-inject and proxy integration.
- Vs. 1Password: CLI/proxy only, no browser/cloud.
- Import: Manual adds for now; post-MVP planned.
- Forgot pw: No recovery—design choice.
- Windows: WSL ok, native not planned.
- Backups: Export to encrypted file.

## Contributing

PRs for: fixes, docs, tests, ports (e.g., BSD).

Avoid: Features like GUI/cloud; deps.

Keep auditable and offline-first.

## License

MIT. ChaCha20 public domain.

## Contact

GitHub: @gnarzilla  
Email: gnarzilla@deadlight.boo
