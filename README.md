# Networks CA1 Project
**Automated Container deployment and Administration in the cloud**  
Network Systems and Administration - B9IS121

**Group members:**  
Nithyanantham Sanjeevi -  20097281
Alexandre Peres Oliveira da Silva - 20096284  
Okeke Munachukwudinamma Praise - 20102055  
Spencer John - 20099070 

**Repositories**:  
[Main project repository - the only repository needed to run the project](https://github.com/dbsspencerjohn-dot/ca1networks.git)  

Auxiliary/intermediary repositories:  
[Docker setup repository - fork of the app repository](https://github.com/alex-silverr/nithyanands-irish-visa-tracker.git)  
[Web app used for the demo - Nithyanantham's Irish visa tracker](https://github.com/nithyanands/irish-visa-tracker.git)  
[Former setup repository - old main repository](https://github.com/dbsspencerjohn-dot/networking_ca1.git)

----

**Technologies Used:**
| Part      | Technology | Group Member Responsible |
| ----------- | ----------- | ----------- |
| Infrastructure Setup      | Terraform | Spencer John |
| Configuration Management   | Ansible | Okeke M. Praise |
| Docker Container Deployment | Docker | Alexandre P. Silva |
|CI/CD Pipeline Integration | Git Actions | Nithyanantham Sanjeevi |


## Part 1 - Terraform

### Setup
- Install terraform
- Install ansible
- Install AWS CLI
- Create an IAM USER
- Configure your AWS CLI with the IAM user Access ID and Access Key
- Your AWS region when configuring AWS CLI should be us-east-1 ---> eu-east-1

### Executing terraform
UP:
- ``terraform init``
- optional: ``terraform plan``
- ``terraform apply``

DOWN:
- ``terraform destroy``

## Part 2 - Ansible

## Part 3 - Docker

### Structure
**Docker Compose:**   
``docker-compose.yaml``  
This file sets up the service to run the container. It automates the arguments and options on a ``docker run`` command, making permanent settings instead of having to declare them every time the container is (re-)created or started.
- ``build: .`` instructs the composer to build the Dockerfile located on the same folder.
- ``container_name: visa-tracker`` sets the container name as *"visa-tracker*.
- ``tty: true`` makes it possible to execute the bash/shell inside the container.
- ``ports:`` specifies container ports connections to be accessed from outside.
  - ``8501:8501`` connects the internal port 8501 to external port 8501.



**Dockerfile:**  
``Dockerfile``  
This is the file that informs the container build instructions, and the main command to execute/deploy the app within it.
- ``FROM python:3.13`` declares the use of the Docker Python 3.13 image.
- ``WORKDIR /usr/local/app`` sets the internal working directory on the container to ``usr/local/app``.
- ``RUN apt-get update``*[...]* updates the ``apt-get`` command and allows for git integration.
- ``COPY requirements.txt ./`` copies the ``requirements.txt`` file from the external folder to the inside of the container.
  - ``requirements.txt`` is a file typical in Python projects listing the library dependencies necessary to run the project.
  - If these requirements change, such as new libraries being added, it's necessary to remake the ``requirements.txt`` file.
  - To do so, run the command ``pip freeze > requirements.txt`` on an environment that has all the libraries installed. 
- ``RUN pip install --no-cache-dir -r requirements.txt`` installs the library dependencies on the container.
- ``COPY . .`` copies files in the same folder as the ``Dockerfile`` to the container's working firectory.
- ``EXPOSE 8501`` exposes port 8501 for deployment of the Streamlit app.
- ``HEALTHCHECK CMD curl --fail http://localhost:8501/_stcore/health`` verifies if the exposed port 8501 is working correctly.
- ``CMD ["streamlit", "run", "app.py", "--server.port=8501", "--server.address=0.0.0.0" ]`` executes the Streamlit app ``app.py`` on port 8501.

### How to use
UP:
- Go to the folder where ``docker-compose.yaml`` is
- If there was a change in the app: ``docker compose up --build -d``
- If there was no change in the app: ``docker compose up -d``

DOWN:
- Go to the folder where ``docker-compose.yaml`` is
- ``docker compose down``

MAINTENANCE:
- See logs: ``docker container logs visa-tracker``
- Access container shell: ``docker exec -it visa-tracker sh``

## Part 4 - Git Actions

### Approach
GitHub Actions rebuilds and redeploys the app on every push to `main`. No container registry is used — the runner SSHes into the EC2 instance and builds the image directly on the host, keeping the pipeline simple with fewer secrets/failure points.

### Prerequisites
- GitHub CLI (`gh`) installed and authenticated with `repo` + `workflow` scopes
- Personal Access Token includes the `workflow` scope (required to push files under `.github/workflows/`)
- `EC2_HOST` repository secret set to the current instance public IP
- `EC2_SSH_PRIVATE_KEY` repository secret set to the full private key contents
- Repo cloned on the EC2 instance and owned by `ubuntu`, not `root`
- `git config --global --add safe.directory <repo-path>` set on the EC2 instance
- `.github/workflows/deploy.yml` present and committed

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
