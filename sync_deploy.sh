
set -euo pipefail

REPO="nithyanands/nsca1networks"
KEY_PATH="~/.ssh/id_rsa"

echo "Reading current public IP from Terraform state..."
PUBLIC_IP=$(terraform output -raw instance_public_ip)

if [ -z "$PUBLIC_IP" ]; then
  echo "ERROR: Could not read instance_public_ip from Terraform output."
  echo "Make sure you're running this from the folder with your .tf files"
  echo "and that 'terraform apply' has completed successfully."
  exit 1
fi

echo "Current public IP: $PUBLIC_IP"

echo "Updating host_file.ini..."
cat > host_file.ini <<EOF
[web]
${PUBLIC_IP} ansible_user=ubuntu ansible_ssh_private_key_file=${KEY_PATH} ansible_ssh_common_args='-o StrictHostKeyChecking=no'
EOF
echo "host_file.ini updated."

echo "Updating GitHub secret EC2_HOST on $REPO..."
gh secret set EC2_HOST --repo "$REPO" --body "$PUBLIC_IP"
echo "GitHub secret EC2_HOST updated."

echo ""
echo "Done. New IP is live in both host_file.ini and the GitHub EC2_HOST secret: $PUBLIC_IP"
echo "Reminder: run the Ansible playbook next if this is a fresh instance:"
echo "  ansible-playbook -i host_file.ini docker_v2.yaml"
echo "If the container didn't survive a restart, check:"
echo "  docker ps -a   (on the instance)"
