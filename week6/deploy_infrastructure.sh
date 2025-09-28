#!/bin/bash
# Set region and key pair path
KEY_PATH="my-key-pair.pem"
PUBLIC_IP=$(cat instance_ip.txt)
if [ -z "$PUBLIC_IP" ]; then
echo "Public IP not found."
exit 1
fi
echo "Deploying NGINX to $PUBLIC_IP..."
# SSH into the EC2 instance and install NGINX
while ! ssh -o "StrictHostKeyChecking=no" -i $KEY_PATH ubuntu@$PUBLIC_IP "exit" 2>/dev/null; do
echo "Waiting for EC2 instance to be ready..."
sleep 10

done
sudo apt update -y # Update package lists
sudo apt install -y nginx # Install NGINX
sudo systemctl enable nginx # Enable NGINX to start on boot
sudo systemctl start nginx # Start NGINX service
# Create a simple HTML page
echo "<html><body><h1>Welcome to My NGINX Site!</h1></body></html>" | sudo tee /var/www/html/index.html
EOF
echo "Site deployed at: http://$PUBLIC_IP"
