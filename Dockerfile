FROM python:3.13
# Set working directory
WORKDIR /usr/local/app

# Update apt-get update and upgrade for git integration
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y git

# Install the application python dependencies from "requirements.txt" file
# If requirements change, remake "requirements.txt" by executing "pip freeze > requirements.txt"
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# Copy source code from the external folder to the container
COPY . .

# Exposes port 8501
EXPOSE 8501

# Verifies functioning of exposed port 8501
HEALTHCHECK CMD curl --fail http://localhost:8501/_stcore/health


# Executes "app.py" through Streamlit on port 8501
CMD ["streamlit", "run", "app.py", "--server.port=8501", "--server.address=0.0.0.0" ]