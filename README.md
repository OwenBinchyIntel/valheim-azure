# Valheim Azure VM Deployment

This repository contains Infrastructure as Code (IaC) for deploying a Valheim dedicated server on Azure Virtual Machine using Azure Bicep.

## Architecture

The deployment creates:
- **Virtual Network** with a dedicated subnet
- **Network Security Group (NSG)** with rules for SSH (port 22) and Valheim (UDP ports 2456-2458)
- **Ubuntu 22.04 LTS VM** with SteamCMD and Valheim server
- **Azure Files mount** for persistent world storage
- **systemd service** for automatic Valheim server management

## Prerequisites

Before deploying, you need:

1. **Azure CLI** installed ([Install guide](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli))
2. **Azure subscription** with appropriate permissions
3. **SSH key pair** for VM access
4. **Existing Azure Storage Account** with an Azure File Share for world saves

## Quick Start

### 1. Clone the repository

```bash
git clone https://github.com/OwenBinchyIntel/valheim-azure.git
cd valheim-azure
```

### 2. Configure parameters

Edit `infra/main.parameters.json` with your values:

```json
{
  "parameters": {
    "adminUsername": { "value": "your-username" },
    "sshSourceCidr": { "value": "YOUR_IP/32" },
    "storageAccountName": { "value": "your-storage-account" },
    "fileShareName": { "value": "your-file-share" },
    "worldsDir": { "value": "worlds_local" }
  }
}
```

### 3. Customize server settings (Optional)

Edit `infra/cloud-init/valheim.yaml` to customize:
- `SERVER_NAME` - Your server name (default: "OwenValheim")
- `WORLD_NAME` - World name (default: "OahuHawaii")
- `PORT` - Server port (default: 2456)
- `PUBLIC` - Public visibility (1 = visible, 0 = private)

**Note**: The server password is passed as a secure parameter during deployment (see step 4).

### 4. Deploy to Azure

```bash
# Login to Azure
az login

# Create a resource group
az group create --name rg-valheim-vm --location northeurope

# Deploy the infrastructure
az deployment group create \
  --resource-group rg-valheim-vm \
  --template-file infra/main.bicep \
  --parameters infra/main.parameters.json \
  --parameters adminSshPublicKey="$(cat ~/.ssh/id_rsa.pub)" \
  --parameters storageAccountKey="YOUR_STORAGE_KEY" \
  --parameters serverPass="YOUR_SECURE_PASSWORD"
```

### 5. Get the public IP

```bash
az deployment group list \
  --resource-group rg-valheim-vm \
  --query "[?properties.provisioningState=='Succeeded'] | [-1].properties.outputs.publicIp.value" \
  -o tsv
```

### 6. Connect to your server

In Valheim:
1. Open the Community tab
2. Click "Join Game"
3. Enter the public IP and port (e.g., `1.2.3.4:2456`)
4. Enter your server password

## Configuration

### VM Sizing

The default VM size is `Standard_B2ms` (2 vCPUs, 8 GB RAM) suitable for 2-6 players. For larger servers, update the `vmSize` parameter:

- **2-4 players**: Standard_B2ms (2 vCPU, 8 GB)
- **5-8 players**: Standard_D2s_v3 (2 vCPU, 8 GB) or Standard_B4ms (4 vCPU, 16 GB)
- **8+ players**: Standard_D4s_v3 (4 vCPU, 16 GB) or higher

### Network Security

#### SSH Access
By default, SSH is allowed from any IP (`*`).  
For better security, restrict SSH access to your public IP:

```json
"sshSourceCidr": { "value": "YOUR_PUBLIC_IP/32" }
```

To find your public IP:
```bash
curl https://api.ipify.org
```

#### Valheim Ports
The deployment opens UDP ports 2456-2458 for Valheim game traffic from all sources.

## Management

### SSH into the VM

```bash
ssh your-username@PUBLIC_IP
```

### Check server status

```bash
sudo systemctl status valheim
```

### View server logs

```bash
sudo journalctl -u valheim -f
```

### Restart the server

```bash
sudo systemctl restart valheim
```

### Stop the server

```bash
sudo systemctl stop valheim
```

## World Persistence

World saves are stored in Azure Files at `/mnt/valheim/worlds_local/` by default. This ensures:
- **Persistence** across VM restarts or replacements
- **Backup capability** through Azure Files snapshots
- **Portability** to move worlds between deployments

> Note: Azure Files performance is more than sufficient for small Valheim servers (2–6 players).  
> For heavily modded servers or larger player counts, a managed disk may be preferred.


## Cost Optimization

To minimize costs when not playing:

### Deallocate the VM
```bash
az vm deallocate --resource-group rg-valheim-vm --name valheim-vm
```

### Start the VM
```bash
az vm start --resource-group rg-valheim-vm --name valheim-vm
```

**Note**: The public IP will remain the same after deallocation, as a Static Standard Public IP is used.


## Security Best Practices

### ⚠️ Critical Security Items

1. **Use a strong server password** - Pass `serverPass` parameter securely during deployment
2. **Protect sensitive parameters**:
   - Never commit `storageAccountKey` or `serverPass` to version control
   - Use Azure Key Vault for production deployments
   - Pass sensitive values via command-line parameters

### Example with Key Vault

```bash
read -s -p "Storage account key: " STORAGE_KEY; echo
read -s -p "Server password: " SERVER_PASS; echo

az deployment group create \
  --resource-group rg-valheim-vm \
  --template-file infra/main.bicep \
  --parameters infra/main.parameters.json \
  --parameters adminSshPublicKey="$(cat ~/.ssh/id_rsa.pub)" \
  --parameters storageAccountKey="$STORAGE_KEY" \
  --parameters serverPass="$SERVER_PASS"

```

## Troubleshooting

### Server won't start
1. SSH into the VM
2. Check logs: `sudo journalctl -u valheim -f`
3. Verify Azure Files mount: `mount | grep cifs`
4. Check Steam installation: `ls -la /opt/valheim`

### Can't connect to server
1. Verify NSG rules allow UDP 2456-2458
2. Check server is running: `sudo systemctl status valheim`
3. Confirm public IP hasn't changed
4. Verify server password is correct

### Azure Files mount fails
1. Check storage account credentials
2. Verify file share exists
3. Check network connectivity: `ping your-storage-account.file.core.windows.net`

## Cleanup

To delete all resources:

```bash
az group delete --name rg-valheim-vm --yes
```

**Note**: This will delete the VM but not the Azure Storage Account with your world saves.

## Contributing

Contributions are welcome! Please open an issue or submit a pull request.

## License

This project is provided as-is for educational and personal use.

## Acknowledgments

- Built with Azure Bicep
- Uses SteamCMD for Valheim server installation
- Inspired by the Valheim community

## Roadmap

Planned enhancements:
- Azure Function + Discord bot for start/stop/status control
- Managed Identity + Key Vault integration (no secrets in deployment)
- Identity-based authentication for Azure Files
- Optional automation for backups and snapshots
