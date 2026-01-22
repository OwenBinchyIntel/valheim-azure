# Copilot Instructions for Valheim Azure IaC

## Project Overview

This is an **Azure Infrastructure-as-Code** project that deploys a Valheim dedicated game server on Azure VMs using **Bicep** (Azure's domain-specific language for infrastructure). The deployment is single-resource-group scoped and orchestrates three core components: networking, security, and compute with game server provisioning.

## Architecture & Data Flow

**Key Pattern**: Modular composition where `main.bicep` orchestrates reusable modules that have clear input/output contracts.

- **`main.bicep`** (root orchestrator): References three modules sequentially, passes outputs forward (e.g., `network.outputs.subnetId` → `nsg` and `vm`)
- **`modules/network.bicep`**: Creates vNet (10.10.0.0/16) and subnet (10.10.1.0/24); outputs `subnetId`
- **`modules/nsg.bicep`**: Associates security rules to the subnet; manages SSH (TCP 22) and Valheim (UDP 2456-2458) ingress
- **`modules/vm.bicep`**: Provisions Ubuntu 22.04 LTS VM; embeds cloud-init script that mounts Azure Files and starts Valheim server
- **`cloud-init/valheim.yaml`**: Cloud-init template with 5 placeholder tokens (`__STORAGE_ACCOUNT__`, `__FILE_SHARE__`, `__STORAGE_KEY__`, `__WORLDS_DIR__`, `__SERVER_PASS__`) injected by `vm.bicep` via `replace()` calls

**Data Flow**: Parameters → main.bicep → module composition → cloud-init rendering → VM provisioning → Valheim startup

## Critical Developer Workflows

### Deployment
```bash
# Parameters file is mandatory; ensure all secure parameters are populated
az deployment group create --resource-group <rg> \
  --template-file infra/main.bicep \
  --parameters @infra/main.parameters.json
```

**Pre-requisites** (not handled by IaC):
- Azure Storage Account & File Share must exist before deployment
- SSH public key required in parameters
- Storage account key (sensitive) must be provided at deploy time
- `sshSourceCidr` should be restricted (not `*`) in production

### Testing Changes
- **Syntax validation**: `az bicep build infra/main.bicep`
- **What-if preview**: `az deployment group what-if --resource-group <rg> --template-file infra/main.bicep --parameters @infra/main.parameters.json`
- **Cloud-init debugging**: SSH to VM, check `/var/log/cloud-init-output.log`

## Key Patterns & Conventions

### Bicep Module Structure
- All modules are **parameterized** and **targetScope** is `resourceGroup` (root)
- Module references use **symbolic names** (`module network './modules/network.bicep'`) and output access is explicit (`network.outputs.subnetId`)
- **@secure()** decorator marks sensitive parameters (SSH key, storage key, server password) — never logged

### Cloud-Init Token Substitution
Template tokens are **uppercase with double underscores** (`__TOKEN__`). The vm.bicep uses **nested `replace()`** calls (5 levels deep) to render the template:
```bicep
var renderedCloudInit = replace(replace(replace(..., '__STORAGE_ACCOUNT__', storageAccountName), ...), '__SERVER_PASS__', serverPass)
```
When modifying tokens, update **both** the template in `cloud-init/valheim.yaml` and the corresponding `replace()` chain in `vm.bicep`.

### Naming Conventions
- All resources prefixed with `namePrefix` parameter (default: `'valheim'`) for multi-deployment isolation
- Resource names concatenate prefix + resource type: `'${namePrefix}-vm'`, `'${namePrefix}-nsg'`

### Network Security
- **NSG priority order matters**: SSH (100) is evaluated before Valheim-UDP (110)
- **SSH is restricted by default** to `sshSourceCidr` (CIDR notation required, e.g., `"1.2.3.4/32"`)
- **Valheim ports** (2456-2458 UDP) are open to `*` (internet-facing game server)

## Integration Points & External Dependencies

### Azure Files Mount
- VM uses **SMB 3.1.1** to mount Azure File Share at `/mnt/valheim`
- Credentials stored in `/etc/smbcredentials/` (root-only, mode 0600)
- fstab entry includes `nofail` to tolerate transient mount failures during boot
- World saves live at `/mnt/valheim/__WORLDS_DIR__` (parameter-driven path)

### systemd Service
- `valheim.service` runs Valheim server as `valheim` user with `SteamAppId=896660`
- Restart policy: `on-failure` with 10-second backoff (`RestartSec=10`)
- High file descriptor limit (`LimitNOFILE=100000`) for player connections

### SteamCMD Integration
- Installed via cloud-init package manager; **not explicitly invoked** in current config
- If server binary missing, manual SSH + `steamcmd` download required (opportunity for automation)

## Common Modifications

**Add a parameter**: Define in all three layers:
1. `main.bicep` (param block)
2. `main.parameters.json` (parameters section)
3. Relevant module (if needed) and pass via module reference

**Adjust VM size**: Edit `vmSize` parameter (defaults to `Standard_D2s_v5`); common Valheim sizes are `Standard_B2ms` (2-6 players) to `Standard_D4s_v5` (larger servers)

**Change network ranges**: Modify address prefixes in `modules/network.bicep` (vNet 10.10.0.0/16, subnet 10.10.1.0/24)

**Update Valheim server config**: Edit `cloud-init/valheim.yaml` start_valheim.sh script (SERVER_NAME, WORLD_NAME, PORT, PUBLIC flag), then re-deploy

**Add new NSG rule**: Insert into `modules/nsg.bicep` securityRules array, set priority > 110 to avoid conflicts

## File Structure Summary

```
infra/
├── main.bicep                    # Orchestrator: deploys all modules
├── main.parameters.json          # Parameter values (git-ignored: storage key, SSH key)
├── cloud-init/
│   └── valheim.yaml             # Cloud-init template with 5 token placeholders
└── modules/
    ├── network.bicep             # vNet + subnet (outputs: vnetName, subnetId)
    ├── nsg.bicep                 # NSG rules + subnet association
    └── vm.bicep                  # VM + NIC + PIP; renders & injects cloud-init
```

## Gotchas & Debugging

- **Storage key in parameters**: Currently passed as a secure parameter; **never commit** to version control. Use Azure Key Vault in production.
- **Cloud-init template token mismatches**: If a token in valheim.yaml is missing its replace() call in vm.bicep, it will remain as `__LITERAL__` in the deployed script.
- **Azure Files mount failures**: Check VM logs (`cloud-init-output.log`) for SMB negotiation errors; verify storage account key and file share existence before deployment.
- **Valheim won't start**: SSH to VM, check `/opt/valheim/start_valheim.sh` has 0755 permissions and `/mnt/valheim` mount is active (`mount | grep valheim`).
