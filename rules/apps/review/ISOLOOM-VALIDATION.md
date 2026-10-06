# Review: `isoloom.yml` and both editions

Review must validate isoloom.yml, the generated .isoloom/ files, and both the Docker and the VM edition.

## Requirements
- `isoloom validate` passes and `isoloom check` passes (`.isoloom/` is current; nothing in it was
  edited by hand).
- No root `docker-compose.yml`, no `build/docker-compose.dev.yml`, no `deploy/` folder.
- Every machine has `docker:` and `vm:`, or the review records why the lab is VM-only (or
  Docker-only) and the metadata `providers` match.
- Ports: each service listens on its declared `services:` port on both editions; only the
  player's entry point has `publish:`.
- Evidence: inputs declared at the top and on the claiming machine; a `volumes:` path keeps the
  claimed value; claim + placement run in `docker.init` and in `vm.provision`.
- Docker edition: `isoloom run docker .` comes up healthy and `isoloom test docker .` passes
  (the declared checks, the derived reachability ones, `build/check/check.sh`).
- VM edition: `isoloom run vagrant .` provisions without errors and `isoloom test vagrant .`
  passes (when Vagrant is available; otherwise record that it was not run).
- Security: non-root app users where applicable, on both editions.
- Record any deviation under Isoloom findings in `.ctf/REVIEW.md`.
