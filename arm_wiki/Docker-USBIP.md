# Docker with USB/IP (Windows usbipd-win → container)

Use an optical drive attached to another (Windows) machine inside the ARM container, with the `usbip` client running **in the container**.

## How it works
- Windows runs the server (`usbipd-win`) and shares the drive over TCP port 3240.
- `Dockerfile.usbip` extends the ARM image with the `usbip` client and an init script (`scripts/docker/runit/usbip_attach.sh`) that runs `usbip attach` at start-up.
- `docker-compose.usbip.yml` runs it privileged, with `/sys` and `/dev` bind-mounted so the new `/dev/sr0` is visible.

## Host prerequisites (cannot be done in the container)
Containers share the host kernel. The Docker host needs the modules:
```bash
sudo modprobe vhci-hcd sr_mod usb-storage
```
Add them to `/etc/modules-load.d/usbip.conf` to persist. Docker Desktop / WSL kernels may lack `vhci-hcd`; a custom kernel may be required.

## Steps
1. On Windows (admin): `usbipd list`, then `usbipd bind --busid <busid>`. Allow TCP 3240 in the Windows firewall.
2. Edit `USBIP_SERVER` (Windows IP) and `USBIP_BUSID` in `docker-compose.usbip.yml`, plus the volume paths.
3. `docker compose -f docker-compose.usbip.yml up -d --build`
4. Check: `docker logs arm-rippers | grep usbip` and `docker exec arm-rippers ls -l /dev/sr0`.

## Limitations
- Attach is retried at start (`USBIP_RETRIES`, default 10, 5s apart) but is not persistent across network drops; restart the container to re-attach.
- The `/dev` node is created by the host kernel; udev events may need to reach the container for automatic ripping — verify insert/eject triggers a job.
- Reads over the network are slower; Blu-ray may be marginal.
- If attach fails, you can instead attach on the Docker host and pass `/dev/sr0` via `devices:`.

## Option A: attach on the Docker host
Use `docker-compose.usbip-host.yml` with the stock image. On the host:
```bash
sudo apt install linux-tools-generic hwdata
sudo modprobe vhci-hcd sr_mod usb-storage
sudo usbip list -r <windows_ip>
sudo usbip attach -r <windows_ip> -b <busid>
ls -l /dev/sr0
docker compose -f docker-compose.usbip-host.yml up -d
```
Attach before starting the container (the `devices:` mapping fails if `/dev/sr0` is missing). Re-attach after reboots or network drops, e.g. with a systemd unit.
