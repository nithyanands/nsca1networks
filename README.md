# Networks CA1 Project
**Automated Container deployment and Administration in the cloud**  
Network Systems and Administration - B9IS121

**Group members:**  
Nithyanantham Sanjeevi -  
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
