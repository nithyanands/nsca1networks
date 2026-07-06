# ca1networks

## Part 4 - Git Actions

### Approach
GitHub Actions rebuilds and redeploys the app on every push to `main`. No container registry is used — the runner SSHes into the EC2 instance and builds the image directly on the host, keeping the pipeline simple with fewer secrets/failure points.

### Setup
- Two repo secrets required (Settings → Secrets and variables → Actions):

| Secret | Value |
|---|---|
| `EC2_HOST` | EC2 instance's current public IP |
| `EC2_SSH_PRIVATE_KEY` | Private key matching the public key uploaded via Terraform |

- Set via GitHub CLI:
```bash
gh secret set EC2_HOST --repo nithyanands/nsca1networks --body "<public-ip>"
gh secret set EC2_SSH_PRIVATE_KEY --repo nithyanands/nsca1networks < ~/.ssh/id_rsa
```
- PAT must include the `workflow` scope (needed to push files under `.github/workflows/`)

### Workflow file
`.github/workflows/deploy.yml` — on push to `main`, connects to EC2 over SSH and runs:
```bash
cd ~/nsca1networks
git pull origin main
docker compose up --build -d
```

### Verification
```bash
curl -I http://<public-ip>:8501
# HTTP/1.1 200 OK
```

### Related scripts
- **`sync_deploy.sh`** — since no Elastic IP is used, the public IP changes on every stop/restart. This script pulls the current IP from `terraform output`, updates `host_file.ini`, and refreshes the `EC2_HOST` secret. Run manually after any event that changes the IP.
- **`health_check.sh`** — manual diagnostic checking AWS infra, container/server, and app layers in one run. Used before demos or after suspected drift.

### Key issues resolved
1. PAT missing `workflow` scope — blocked pushes to `.github/workflows/`.
2. `missing server host` — `EC2_HOST` secret hadn't been created yet.
3. `detected dubious ownership` on `git pull` — repo cloned as `root` via Ansible; fixed with an ownership-fix task sequenced after clone, before build.
4. `restart: always` not applied to a running container — Docker only applies restart-policy changes on recreation; fixed with `docker compose up -d --force-recreate`.
5. No Elastic IP → public IP changes on restart — accepted as a documented limitation rather than an unresolved bug.
