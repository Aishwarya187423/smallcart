# AWS Infrastructure Setup Guide

## Prerequisites

### 1. AWS Account Setup
- AWS Account with appropriate permissions
- AWS CLI configured with credentials
- IAM user with EC2, VPC creation permissions

### 2. Required Files
- `smallcart.pem` - Your AWS key pair file
- `create_aws_infrastructure.py` - The infrastructure script

### 3. Key Pair Setup
**IMPORTANT**: Before running the script, you need to have the key pair ready:

#### Option A: Upload Existing Key Pair
1. Go to AWS Console → EC2 → Key Pairs
2. Click "Import key pair"
3. Name: `smallcart`
4. Upload your `smallcart.pem` file (public key content)

#### Option B: Create New Key Pair
1. Go to AWS Console → EC2 → Key Pairs  
2. Click "Create key pair"
3. Name: `smallcart`
4. Download the `smallcart.pem` file

## Installation & Setup

### 1. Install AWS Dependencies
```bash
pip install -r aws-requirements.txt
```

### 2. Configure AWS Credentials
```bash
aws configure
```
Enter your:
- AWS Access Key ID
- AWS Secret Access Key  
- Default region (e.g., us-east-1)
- Output format (json)

### 3. Set Key Pair Permissions (Linux/Mac)
```bash
chmod 400 smallcart.pem
```

## Running the Infrastructure Script

### 1. Execute the Script
```bash
python create_aws_infrastructure.py
```

### 2. What the Script Creates
- **VPC**: 10.0.0.0/16 CIDR block
- **Public Subnet**: 10.0.1.0/24 in availability zone 'a'
- **Internet Gateway**: Attached to VPC
- **Route Table**: Routes 0.0.0.0/0 to Internet Gateway
- **Security Group**: Opens ports 22, 80, 443, 5000
- **EC2 Instance**: t3.micro with Amazon Linux 2023

### 3. Security Group Rules
The script creates these inbound rules:
- **Port 22 (SSH)**: Access from 0.0.0.0/0
- **Port 5000 (Flask)**: Access from 0.0.0.0/0  
- **Port 80 (HTTP)**: Access from 0.0.0.0/0
- **Port 443 (HTTPS)**: Access from 0.0.0.0/0

## After Infrastructure Creation

### 1. Connect to Your Instance
```bash
ssh -i smallcart.pem ec2-user@[PUBLIC_IP]
```

### 2. Verify Instance Setup
```bash
# Check if Python is installed
python3 --version

# Check setup log
cat /var/log/smallcart-setup.log

# Check instance status
cat /opt/smallcart/instance-status.txt
```

### 3. Deploy SmallCart Application

#### Upload Application Files
```bash
# Using scp to copy files
scp -i smallcart.pem -r /path/to/smallcart/* ec2-user@[PUBLIC_IP]:/opt/smallcart/

# Or using rsync
rsync -avz -e "ssh -i smallcart.pem" /path/to/smallcart/ ec2-user@[PUBLIC_IP]:/opt/smallcart/
```

#### Install Dependencies & Run
```bash
# SSH into instance
ssh -i smallcart.pem ec2-user@[PUBLIC_IP]

# Navigate to app directory
cd /opt/smallcart

# Install Python dependencies
pip3 install -r requirements.txt

# Run the Flask application
python3 app.py
```

### 4. Access Your Application
- **Flask App**: http://[PUBLIC_IP]:5000
- **Admin Login**: admin@gmail.com / 123456

## Infrastructure Information

The script saves all infrastructure details to `smallcart-infrastructure.json`:
```json
{
  "project_name": "SmallCart",
  "region": "us-east-1",
  "resources": {
    "vpc_id": "vpc-...",
    "subnet_id": "subnet-...",
    "instance_id": "i-...",
    "public_ip": "x.x.x.x"
  },
  "connection_info": {
    "ssh_command": "ssh -i smallcart.pem ec2-user@x.x.x.x",
    "flask_app_url": "http://x.x.x.x:5000"
  }
}
```

## Production Setup (Optional)

### 1. Set up Process Manager
```bash
# Create systemd service
sudo nano /etc/systemd/system/smallcart.service
```

### 2. Configure Nginx Reverse Proxy
```bash
# Install nginx
sudo yum install nginx -y

# Configure reverse proxy to port 5000
sudo nano /etc/nginx/nginx.conf
```

### 3. Set up SSL with Let's Encrypt
```bash
# Install certbot
sudo yum install python3-certbot-nginx -y

# Get SSL certificate
sudo certbot --nginx -d yourdomain.com
```

## Troubleshooting

### Key Pair Issues
- **Error**: Key pair not found
- **Solution**: Create/import key pair named 'smallcart' in AWS Console

### Permission Issues  
- **Error**: SSH permission denied
- **Solution**: `chmod 400 smallcart.pem`

### Instance Connection Issues
- **Error**: Connection timeout
- **Solution**: Check security group allows SSH (port 22)

### Application Issues
- **Error**: Can't access Flask app
- **Solution**: Ensure app runs on 0.0.0.0:5000, not localhost

## Cleanup Resources

To avoid AWS charges, delete resources when done:
```bash
# Terminate EC2 instance
aws ec2 terminate-instances --instance-ids i-1234567890abcdef0

# Delete other resources through AWS Console:
# - Security Group
# - Subnet  
# - Route Table
# - Internet Gateway
# - VPC
```

## Cost Estimation

**Monthly costs (approximate):**
- EC2 t3.micro: $8-10
- Data Transfer: $1-5  
- Storage: $1-2
- **Total**: ~$10-17/month

## Support

For issues:
1. Check AWS CloudWatch logs
2. Verify security group settings
3. Confirm key pair permissions
4. Check instance system logs
