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

## VM-only labs (AD ranges)

Some labs are VM-only: a multi-VM Windows Active Directory range has no container form. Describe
it the same way, with these differences:

- Machines carry only `vm:` (no `docker:`): `os: windows-server-2019` (or another), and a
  per-machine `provision:` step that only sets up WinRM so the controller can reach them.
- The lab is provisioned at the environment level: a top-level `provision:` step points at an
  Ansible playbook with its `requirements:` and inventory `groups`. Isoloom brings up a small
  Debian controller that installs Ansible, generates the inventory (hosts, addresses, WinRM), and
  runs the playbook against the Windows machines over WinRM.
- No `build/`, no container evidence injection, no `tests/` (those run against the Docker
  edition, which a VM-only lab does not have). Keep only the provisioning and the `isoloom.yml`.
- CI covers it without running it: the `isoloom` job validates the spec and that `.isoloom/` is
  current, `vagrant` parses the Vagrantfiles, `terraform` validates the generated modules; the
  live `lab` job is skipped (no `compose.yml`). A multi-VM Windows range cannot run in a CI
  runner, so it is verified by generation, not by a live boot.

## Critical rules (high-signal)

- Every machine gets `docker:` and `vm:` when it can, so the lab runs on every target.
- A service listens on the port its machine declares; `publish:` exposes one to the player.
- DB init: numbered SQL files; create the user before GRANT; separate DB and global privileges.
- Package managers match the base image (Debian: apt-get, Alpine: apk, Oracle: microdnf).
- Evidence: never hard-coded. Claimed into a machine volume (the token is single-use), placed by
  a `docker.init` script and by the VM's provision step.

## CI

`validate.yml` checks the spec, that `.isoloom/` is current, runs the lab with its checks, and
validates every Vagrant and Terraform output. `publish.yml` registers the lab with CyberCTF through
the shared, hardened `CyberCTF/publish-lab-action` (the backend endpoints live in that private
action, not here) and waits for a maintainer to approve it via the `production` environment, so a
push alone never publishes. Both skip the template itself (no `isoloom.yml` yet).

Per lab repo, set up once: a `production` environment with required reviewers, and the
organization secrets `CYBERAUTH_CLIENT_ID` / `CYBERAUTH_CLIENT_SECRET` scoped to it.
