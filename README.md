# Lab Template

The single template for every CyberCTF lab. A lab is described once in `isoloom.yml`
([Isoloom](https://www.isoloom.com)): its machines, their network and services, and how each
machine is produced as a container and as a VM. `isoloom generate` writes the files for every
target under `.isoloom/` (Docker Compose, Vagrant, Terraform), and the CyberCTF launcher runs
them wherever the player chooses: Docker on their machine, local VMs, their own server (ESXi,
Proxmox), any cloud, or hosted. Use `AGENTS.md` and `rules/` as the single source of truth for
requirements.

A complete lab built this way: [CyberCTF/invoice-portal-api](https://github.com/CyberCTF/invoice-portal-api).

## Structure

- `isoloom.yml`: the lab (start from `isoloom.yml.example`)
- `build/<machine>/`: each container machine's `Dockerfile` and `src/` (settings as `ENV` in
  the Dockerfile: Isoloom passes no environment besides the lab's inputs)
- `provision/<machine>.sh`: the same machine as a VM (Debian by default), run as root from
  `/opt/isoloom`
- `build/check/check.sh`: the lab is still solvable, run from the player's side (`checks:`)
- `evidence/claim-evidence.sh`: claims the player's evidence with the launch token; copy it
  next to the machine that holds the evidence (see `rules/apps/run/EVIDENCE-INJECTION.md`)
- `.isoloom/`: generated, committed, never edited (CI fails when it's out of date)
- `tests/`: pytest suite against `.isoloom/docker/compose.yml`
- `.ctf/`: planning and metadata (SCENARIO, EVIDENCE, metadata.json)

## Run it

```bash
isoloom generate
docker compose -f .isoloom/docker/compose.yml up -d --build --wait
docker compose -f .isoloom/docker/compose.yml --profile check run --rm isoloom-check
```

VMs: `cd .isoloom/vagrant && vagrant up`. Install Isoloom with
`cargo install --git https://github.com/isoloom/isoloom isoloom`.

## Critical rules (high-signal)

- Every machine gets `docker:` and `vm:` when it can, so the lab runs on every target.
- A service listens on the port its machine declares; `publish:` exposes one to the player.
- DB init: numbered SQL files; create the user before GRANT; separate DB and global privileges.
- Package managers match the base image (Debian: apt-get, Alpine: apk, Oracle: microdnf).
- Evidence: never hard-coded. Claimed into a machine volume (the token is single-use), placed by
  a `docker.init` script and by the VM's provision step.

## CI

`validate.yml` checks the spec, that `.isoloom/` is current, runs the lab with its checks, and
validates every Vagrant and Terraform output. `publish.yml` registers the lab with CyberCTF from
`.ctf/metadata.json`. Both skip the template itself (no `isoloom.yml` yet).
