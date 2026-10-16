# Docker with USB/IP (Windows usbipd-win → container)

Use an optical drive attached to another (Windows) machine with ARM running in Docker. Windows shares the drive over the network with `usbipd-win`; a Linux `usbip` client attaches it.

## 1. Choose an option
| | Option A: attach on the Docker host | Option B: attach inside the container | Option C: Docker Desktop for Windows (same PC) |
|---|---|---|---|
| Compose file | `docker-compose.usbip-host.yml` | `docker-compose.usbip.yml` | `docker-compose.usbip-wsl.yml` |
| Image | stock ARM image | custom image (`Dockerfile.usbip`) with `usbip` client | stock ARM image |
| Where the drive is | on another (Windows) machine | on another (Windows) machine | on the same Windows PC that runs Docker Desktop |
| Where `usbip attach` runs | on the Docker host, manually | in the container at start-up | `usbipd attach --wsl` in Windows PowerShell |
| Notes | simplest, most reliable | convenient, fully containerised; needs privileged + `/sys` and `/dev` mounts | no network involved; untested, needs a WSL2 kernel with `vhci-hcd` |

Steps 2 and 3 apply to Options A and B. Option C has its own steps. Then follow Option A, B or C.

## 2. Windows setup (both options)
On Windows (admin PowerShell):
```cmd
usbipd list
usbipd bind --busid <busid>
```
Allow TCP port 3240 through the Windows firewall.

## 3. Docker host prerequisites (both options)
Containers share the host kernel, so these cannot be done inside the container. The Docker host needs:
```bash
sudo modprobe vhci-hcd sr_mod usb-storage
```
Add them to `/etc/modules-load.d/usbip.conf` to persist. Docker Desktop / WSL kernels may lack `vhci-hcd`; a custom kernel may be required.

## 4. Option A: attach on the Docker host
Uses `docker-compose.usbip-host.yml` with the stock image.

1. Install the client and attach the drive on the host:
   ```bash
   sudo apt install linux-tools-generic hwdata
   sudo usbip list -r <windows_ip>
   sudo usbip attach -r <windows_ip> -b <busid>
   ls -l /dev/sr0
   ```
2. Edit the volume paths in `docker-compose.usbip-host.yml`.
3. Start the container: `docker compose -f docker-compose.usbip-host.yml up -d`

Attach before starting the container (the `devices:` mapping fails if `/dev/sr0` is missing). Re-attach after reboots or network drops, e.g. with a systemd unit.

## 5. Option B: attach inside the container
### How it works
- `Dockerfile.usbip` extends the ARM image with the `usbip` client and an init script (`scripts/docker/runit/usbip_attach.sh`) that runs `usbip attach` at start-up.
- `docker-compose.usbip.yml` runs it privileged, with `/sys` and `/dev` bind-mounted so the new `/dev/sr0` is visible.

### Steps
1. Edit `USBIP_SERVER` (Windows IP) and `USBIP_BUSID` in `docker-compose.usbip.yml`, plus the volume paths.
2. `docker compose -f docker-compose.usbip.yml up -d --build`
3. Check: `docker logs arm-rippers | grep usbip` and `docker exec arm-rippers ls -l /dev/sr0`.

### Limitations
- Attach is retried at start (`USBIP_RETRIES`, default 10, 5s apart) but is not persistent across network drops; restart the container to re-attach.
- The `/dev` node is created by the host kernel; udev events may need to reach the container for automatic ripping — verify insert/eject triggers a job.
- Reads over the network are slower; Blu-ray may be marginal.
- If attach fails, use Option A instead.

## 6. Option C: Docker Desktop for Windows, drive on the same PC
Docker Desktop runs containers in a Linux VM (WSL2), so a Windows drive letter (e.g. `L:`) cannot be passed to a container: `devices:` needs a Linux device node and a volume mount only exposes files, not the raw drive ARM needs. Instead, share the drive from Windows into the WSL2 VM with `usbipd-win`; no network is involved. Works for USB drives only, not internal SATA drives.

> Untested. Docker Desktop's WSL2 VM uses the shared WSL2 kernel, so the kernel needs `vhci-hcd`, `sr_mod` and `usb-storage`. The default WSL2 kernel may lack them and need to be replaced by a custom kernel.

1. In admin PowerShell, find and bind the drive (the drive letter is irrelevant, use the BUSID):
   ```cmd
   usbipd list
   usbipd bind --busid <busid>
   ```
2. Attach it to WSL2 (repeat after reboots or unplugging the drive):
   ```cmd
   usbipd attach --wsl --busid <busid>
   ```
3. Check that `/dev/sr0` exists in WSL: `wsl ls -l /dev/sr0`
4. Edit the volume paths in `docker-compose.usbip-wsl.yml` and start it: `docker compose -f docker-compose.usbip-wsl.yml up -d`

Attach before starting the container (the `devices:` mapping fails if `/dev/sr0` is missing). Prefer paths inside WSL over `C:/...` bind mounts for performance.
