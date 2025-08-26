#!/usr/bin/env python3
"""
AWS Infrastructure Setup Script for SmallCart Application
Creates VPC, Subnet, Internet Gateway, Route Table, Security Group, and EC2 Instance
"""

import boto3
import json
import time
from botocore.exceptions import ClientError

class SmallCartAWSInfrastructure:
    def __init__(self, region='eu-north-1'):
        """Initialize AWS clients"""
        self.region = region
        self.ec2_client = boto3.client('ec2', region_name=region)
        self.ec2_resource = boto3.resource('ec2', region_name=region)
        
        # Infrastructure names and tags
        self.project_name = 'SmallCart'
        self.vpc_cidr = '10.0.0.0/16'
        self.subnet_cidr = '10.0.1.0/24'
        self.key_pair_name = 'smallcart'
        self.ami_id = 'ami-0c4fc5dcabc9df21d'  # Amazon Linux 2023 AMI
        self.instance_type = 't3.micro'
        
        # Store created resources
        self.resources = {
            'vpc_id': 'vpc-06111db1e5a53d537',  # Use existing VPC
            'igw_id': 'igw-07c22c039aab2b501'   # Use existing Internet Gateway
        }
        
    def create_tags(self, resource_id, resource_type):
        """Create tags for AWS resources"""
        tags = [
            {'Key': 'Name', 'Value': f'{self.project_name}-{resource_type}'},
            {'Key': 'Project', 'Value': self.project_name},
            {'Key': 'Environment', 'Value': 'Production'},
            {'Key': 'CreatedBy', 'Value': 'SmallCart-Setup-Script'}
        ]
        
        try:
            self.ec2_client.create_tags(Resources=[resource_id], Tags=tags)
            print(f"✅ Tags created for {resource_type}: {resource_id}")
        except Exception as e:
            print(f"⚠️  Warning: Could not create tags for {resource_id}: {str(e)}")
    
    def create_vpc(self):
        """Create VPC"""
        print("\n🔄 Creating VPC...")
        
        try:
            response = self.ec2_client.create_vpc(
                CidrBlock=self.vpc_cidr
            )
            
            vpc_id = response['Vpc']['VpcId']
            self.resources['vpc_id'] = vpc_id
            
            # Wait for VPC to be available
            waiter = self.ec2_client.get_waiter('vpc_available')
            waiter.wait(VpcIds=[vpc_id])
            
            # Enable DNS support and hostnames
            self.ec2_client.modify_vpc_attribute(
                VpcId=vpc_id,
                EnableDnsSupport={'Value': True}
            )
            
            self.ec2_client.modify_vpc_attribute(
                VpcId=vpc_id,
                EnableDnsHostnames={'Value': True}
            )
            
            self.create_tags(vpc_id, 'VPC')
            print(f"✅ VPC created successfully: {vpc_id}")
            return vpc_id
            
        except Exception as e:
            print(f"❌ Error creating VPC: {str(e)}")
            raise
    
    def create_internet_gateway(self):
        """Create and attach Internet Gateway"""
        print("\n🔄 Creating Internet Gateway...")
        
        try:
            # Create Internet Gateway
            response = self.ec2_client.create_internet_gateway()
            igw_id = response['InternetGateway']['InternetGatewayId']
            self.resources['igw_id'] = igw_id
            
            self.create_tags(igw_id, 'InternetGateway')
            
            # Attach to VPC
            self.ec2_client.attach_internet_gateway(
                InternetGatewayId=igw_id,
                VpcId=self.resources['vpc_id']
            )
            
            print(f"✅ Internet Gateway created and attached: {igw_id}")
            return igw_id
            
        except Exception as e:
            print(f"❌ Error creating Internet Gateway: {str(e)}")
            raise
    
    def create_subnet(self):
        """Create public subnet"""
        print("\n🔄 Creating Public Subnet...")
        
        try:
            response = self.ec2_client.create_subnet(
                VpcId=self.resources['vpc_id'],
                CidrBlock=self.subnet_cidr,
                AvailabilityZone=f'{self.region}a'
            )
            
            subnet_id = response['Subnet']['SubnetId']
            self.resources['subnet_id'] = subnet_id
            
            # Wait for subnet to be available
            waiter = self.ec2_client.get_waiter('subnet_available')
            waiter.wait(SubnetIds=[subnet_id])
            
            # Enable auto-assign public IP after creation
            self.ec2_client.modify_subnet_attribute(
                SubnetId=subnet_id,
                MapPublicIpOnLaunch={'Value': True}
            )
            
            self.create_tags(subnet_id, 'PublicSubnet')
            print(f"✅ Public Subnet created with auto-assign public IP: {subnet_id}")
            return subnet_id
            
        except Exception as e:
            print(f"❌ Error creating subnet: {str(e)}")
            raise
    
    def create_route_table(self):
        """Create route table and add route to Internet Gateway"""
        print("\n🔄 Creating Route Table...")
        
        try:
            # Create route table
            response = self.ec2_client.create_route_table(
                VpcId=self.resources['vpc_id']
            )
            
            route_table_id = response['RouteTable']['RouteTableId']
            self.resources['route_table_id'] = route_table_id
            
            self.create_tags(route_table_id, 'PublicRouteTable')
            
            # Create route to Internet Gateway
            self.ec2_client.create_route(
                RouteTableId=route_table_id,
                DestinationCidrBlock='0.0.0.0/0',
                GatewayId=self.resources['igw_id']
            )
            
            # Associate route table with subnet
            self.ec2_client.associate_route_table(
                RouteTableId=route_table_id,
                SubnetId=self.resources['subnet_id']
            )
            
            print(f"✅ Route Table created and configured: {route_table_id}")
            return route_table_id
            
        except Exception as e:
            print(f"❌ Error creating route table: {str(e)}")
            raise
    
    def create_security_group(self):
        """Create security group with rules for SSH and Flask app"""
        print("\n🔄 Creating Security Group...")
        
        try:
            # Create security group
            response = self.ec2_client.create_security_group(
                GroupName=f'{self.project_name}-SecurityGroup',
                Description='Security group for SmallCart Flask application',
                VpcId=self.resources['vpc_id']
            )
            
            security_group_id = response['GroupId']
            self.resources['security_group_id'] = security_group_id
            
            self.create_tags(security_group_id, 'SecurityGroup')
            
            # Add inbound rules
            security_rules = [
                {
                    'IpProtocol': 'tcp',
                    'FromPort': 22,
                    'ToPort': 22,
                    'IpRanges': [{'CidrIp': '0.0.0.0/0', 'Description': 'SSH access from anywhere'}]
                },
                {
                    'IpProtocol': 'tcp',
                    'FromPort': 5000,
                    'ToPort': 5000,
                    'IpRanges': [{'CidrIp': '0.0.0.0/0', 'Description': 'Flask app access from anywhere'}]
                },
                {
                    'IpProtocol': 'tcp',
                    'FromPort': 80,
                    'ToPort': 80,
                    'IpRanges': [{'CidrIp': '0.0.0.0/0', 'Description': 'HTTP access from anywhere'}]
                },
                {
                    'IpProtocol': 'tcp',
                    'FromPort': 443,
                    'ToPort': 443,
                    'IpRanges': [{'CidrIp': '0.0.0.0/0', 'Description': 'HTTPS access from anywhere'}]
                }
            ]
            
            self.ec2_client.authorize_security_group_ingress(
                GroupId=security_group_id,
                IpPermissions=security_rules
            )
            
            print(f"✅ Security Group created with rules: {security_group_id}")
            print("   📝 Allowed inbound ports: 22 (SSH), 5000 (Flask), 80 (HTTP), 443 (HTTPS)")
            return security_group_id
            
        except Exception as e:
            print(f"❌ Error creating security group: {str(e)}")
            raise
    
    def check_key_pair(self):
        """Check if key pair exists"""
        print(f"\n🔄 Checking for key pair: {self.key_pair_name}")
        
        try:
            response = self.ec2_client.describe_key_pairs(
                KeyNames=[self.key_pair_name]
            )
            print(f"✅ Key pair '{self.key_pair_name}' exists")
            return True
            
        except ClientError as e:
            if e.response['Error']['Code'] == 'InvalidKeyPair.NotFound':
                print(f"❌ Key pair '{self.key_pair_name}' not found!")
                print(f"   Please create key pair '{self.key_pair_name}' in AWS Console first")
                print(f"   Or upload your smallcart.pem file to AWS as a key pair")
                return False
            else:
                print(f"❌ Error checking key pair: {str(e)}")
                return False
    
    def create_ec2_instance(self):
        """Create EC2 instance"""
        print("\n🔄 Creating EC2 Instance...")
        
        # User data script to set up the instance
        user_data_script = """#!/bin/bash
# Update system
sudo yum update -y

# Install Python 3 and pip
sudo yum install -y python3 python3-pip git

# Install required system packages
sudo yum install -y gcc python3-devel

# Create application directory
sudo mkdir -p /opt/smallcart
sudo chown ec2-user:ec2-user /opt/smallcart

# Set up log file
sudo touch /var/log/smallcart-setup.log
sudo chown ec2-user:ec2-user /var/log/smallcart-setup.log

# Log setup completion
echo "$(date): SmallCart EC2 instance setup completed" >> /var/log/smallcart-setup.log
echo "$(date): Python version: $(python3 --version)" >> /var/log/smallcart-setup.log
echo "$(date): Pip version: $(pip3 --version)" >> /var/log/smallcart-setup.log

# Create a simple status file
echo "EC2 Instance ready for SmallCart deployment" > /opt/smallcart/instance-status.txt
echo "Setup completed at: $(date)" >> /opt/smallcart/instance-status.txt
"""
        
        try:
            response = self.ec2_client.run_instances(
                ImageId=self.ami_id,
                MinCount=1,
                MaxCount=1,
                InstanceType=self.instance_type,
                KeyName=self.key_pair_name,
                SecurityGroupIds=[self.resources['security_group_id']],
                SubnetId=self.resources['subnet_id'],
                UserData=user_data_script,
                TagSpecifications=[
                    {
                        'ResourceType': 'instance',
                        'Tags': [
                            {'Key': 'Name', 'Value': f'{self.project_name}-Instance'},
                            {'Key': 'Project', 'Value': self.project_name},
                            {'Key': 'Environment', 'Value': 'Production'},
                            {'Key': 'Application', 'Value': 'SmallCart-Flask-App'}
                        ]
                    }
                ]
            )
            
            instance_id = response['Instances'][0]['InstanceId']
            self.resources['instance_id'] = instance_id
            
            print(f"✅ EC2 Instance created: {instance_id}")
            print("   🔄 Waiting for instance to be in running state...")
            
            # Wait for instance to be running
            waiter = self.ec2_client.get_waiter('instance_running')
            waiter.wait(InstanceIds=[instance_id])
            
            # Get instance details
            instances = self.ec2_client.describe_instances(InstanceIds=[instance_id])
            instance = instances['Reservations'][0]['Instances'][0]
            
            public_ip = instance.get('PublicIpAddress')
            private_ip = instance.get('PrivateIpAddress')
            
            self.resources['public_ip'] = public_ip
            self.resources['private_ip'] = private_ip
            
            print(f"✅ Instance is now running!")
            print(f"   📍 Public IP: {public_ip}")
            print(f"   📍 Private IP: {private_ip}")
            
            return instance_id
            
        except Exception as e:
            print(f"❌ Error creating EC2 instance: {str(e)}")
            raise
    
    def save_infrastructure_info(self):
        """Save infrastructure information to a JSON file"""
        print("\n💾 Saving infrastructure information...")
        
        infrastructure_info = {
            'project_name': self.project_name,
            'region': self.region,
            'created_at': time.strftime('%Y-%m-%d %H:%M:%S'),
            'resources': self.resources,
            'connection_info': {
                'ssh_command': f"ssh -i smallcart.pem ec2-user@{self.resources.get('public_ip', 'PENDING')}",
                'flask_app_url': f"http://{self.resources.get('public_ip', 'PENDING')}:5000",
                'key_pair': self.key_pair_name,
                'ami_id': self.ami_id,
                'instance_type': self.instance_type
            },
            'next_steps': [
                "Connect to instance using SSH",
                "Deploy SmallCart Flask application",
                "Configure application to run on 0.0.0.0:5000",
                "Set up process manager (systemd or supervisor)",
                "Configure domain name (optional)"
            ]
        }
        
        try:
            with open('smallcart-infrastructure.json', 'w') as f:
                json.dump(infrastructure_info, f, indent=2)
            
            print("✅ Infrastructure information saved to 'smallcart-infrastructure.json'")
            return infrastructure_info
            
        except Exception as e:
            print(f"⚠️  Warning: Could not save infrastructure info: {str(e)}")
            return infrastructure_info
    
    def print_summary(self):
        """Print deployment summary"""
        print("\n" + "="*80)
        print("🎉 SMALLCART AWS INFRASTRUCTURE DEPLOYMENT COMPLETED!")
        print("="*80)
        
        print(f"\n📋 CREATED RESOURCES:")
        print(f"   • VPC ID: {self.resources.get('vpc_id')}")
        print(f"   • Subnet ID: {self.resources.get('subnet_id')}")
        print(f"   • Internet Gateway ID: {self.resources.get('igw_id')}")
        print(f"   • Route Table ID: {self.resources.get('route_table_id')}")
        print(f"   • Security Group ID: {self.resources.get('security_group_id')}")
        print(f"   • EC2 Instance ID: {self.resources.get('instance_id')}")
        
        print(f"\n🌐 CONNECTION INFORMATION:")
        public_ip = self.resources.get('public_ip')
        if public_ip:
            print(f"   • Public IP Address: {public_ip}")
            print(f"   • SSH Command: ssh -i smallcart.pem ec2-user@{public_ip}")
            print(f"   • Flask App URL: http://{public_ip}:5000")
        else:
            print("   • Public IP: Getting IP address...")
        
        print(f"\n🔐 SECURITY:")
        print(f"   • Key Pair: {self.key_pair_name} (smallcart.pem)")
        print(f"   • Open Ports: 22 (SSH), 5000 (Flask), 80 (HTTP), 443 (HTTPS)")
        print(f"   • Access: 0.0.0.0/0 (Internet-facing)")
        
        print(f"\n📋 NEXT STEPS:")
        print(f"   1. Connect to your instance: ssh -i smallcart.pem ec2-user@{public_ip}")
        print(f"   2. Upload your SmallCart application files")
        print(f"   3. Install Python dependencies: pip3 install -r requirements.txt")
        print(f"   4. Run your Flask app: python3 app.py")
        print(f"   5. Access your app at: http://{public_ip}:5000")
        
        print(f"\n💡 TIPS:")
        print(f"   • The instance is configured with Python 3 and pip")
        print(f"   • Your application directory: /opt/smallcart")
        print(f"   • Check setup logs: /var/log/smallcart-setup.log")
        print(f"   • Infrastructure info saved in: smallcart-infrastructure.json")
        
        print("\n" + "="*80)
    
    def deploy_infrastructure(self):
        """Deploy complete infrastructure"""
        print("🚀 STARTING SMALLCART AWS INFRASTRUCTURE DEPLOYMENT")
        print("="*60)
        
        try:
            # Check if key pair exists
            if not self.check_key_pair():
                print("\n❌ DEPLOYMENT FAILED: Key pair not found")
                print("\n📝 TO FIX THIS:")
                print("   1. Go to AWS Console → EC2 → Key Pairs")
                print("   2. Import your existing 'smallcart.pem' file, OR")
                print("   3. Create a new key pair named 'smallcart'")
                print("   4. Run this script again")
                return False
            
            # Use existing VPC and Internet Gateway
            print(f"\n🔄 Using existing VPC: {self.resources['vpc_id']}")
            print(f"🔄 Using existing Internet Gateway: {self.resources['igw_id']}")
            
            # Create remaining infrastructure components
            self.create_subnet()
            self.create_route_table()
            self.create_security_group()
            self.create_ec2_instance()
            
            # Save infrastructure information
            self.save_infrastructure_info()
            
            # Print summary
            self.print_summary()
            
            return True
            
        except Exception as e:
            print(f"\n❌ DEPLOYMENT FAILED: {str(e)}")
            print("\n🔧 CLEANUP:")
            print("   You may need to manually delete any created resources from AWS Console")
            return False

def main():
    """Main function"""
    print("SmallCart AWS Infrastructure Setup")
    print("This script will create VPC, Subnet, Internet Gateway, Route Table, Security Group, and EC2 Instance")
    print("\nPress Enter to continue or Ctrl+C to cancel...")
    
    try:
        input()
    except KeyboardInterrupt:
        print("\n❌ Deployment cancelled by user")
        return
    
    # Initialize and deploy infrastructure
    infrastructure = SmallCartAWSInfrastructure()
    success = infrastructure.deploy_infrastructure()
    
    if success:
        print("\n✅ Deployment completed successfully!")
    else:
        print("\n❌ Deployment failed!")

if __name__ == '__main__':
    main()
