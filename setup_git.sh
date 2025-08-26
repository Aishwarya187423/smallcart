#!/bin/bash
# Initialize Git repository and setup CI/CD for SmallCart

echo "🔧 Setting up Git repository and CI/CD for SmallCart..."

# Initialize git repository if not already done
if [ ! -d ".git" ]; then
    echo "📁 Initializing Git repository..."
    git init
    
    # Create .gitignore
    cat > .gitignore << 'EOF'
# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
build/
develop-eggs/
dist/
downloads/
eggs/
.eggs/
lib/
lib64/
parts/
sdist/
var/
wheels/
*.egg-info/
.installed.cfg
*.egg
MANIFEST

# Flask
instance/
.webassets-cache

# PyInstaller
*.manifest
*.spec

# Unit test / coverage reports
htmlcov/
.tox/
.nox/
.coverage
.coverage.*
.cache
nosetests.xml
coverage.xml
*.cover
.hypothesis/
.pytest_cache/

# Virtual environments
venv/
ENV/
env/
.venv/

# IDEs
.vscode/
.idea/
*.swp
*.swo

# OS
.DS_Store
.DS_Store?
._*
.Spotlight-V100
.Trashes
ehthumbs.db
Thumbs.db

# Database
*.db
*.sqlite
*.sqlite3

# Logs
*.log

# AWS
.aws/

# OpenTelemetry
.otelcol/

# Backups
backups/
*.backup

# Infrastructure files (keep these local for security)
smallcart.pem
*.pem
smallcart-infrastructure.json
EOF

    echo "✅ Git repository initialized"
else
    echo "✅ Git repository already exists"
fi

# Add all files to git
echo "📦 Adding files to Git..."
git add .
git add .github/workflows/deploy.yml

# Make scripts executable
chmod +x deploy.sh
chmod +x setup_monitoring.sh

# Initial commit
if git diff --cached --quiet; then
    echo "📍 No changes to commit"
else
    git commit -m "Initial SmallCart setup with OpenTelemetry and CI/CD

Features:
- Flask application with Bootstrap 5 UI
- SQLite database with user management
- Admin and customer functionality
- OpenTelemetry instrumentation
- Grafana + Tempo + Prometheus monitoring
- GitHub Actions CI/CD pipeline
- AWS infrastructure automation

Components:
- Flask app with CRUD operations
- User authentication and authorization  
- Shopping cart and order management
- Admin panel for products and orders
- OpenTelemetry traces, metrics, and logs
- Grafana dashboards and alerting
- Automated deployment pipeline"

    echo "✅ Initial commit created"
fi

# Create main branch if using older git
git branch -M main 2>/dev/null || true

echo ""
echo "🎉 Git repository setup complete!"
echo ""
echo "📋 Next Steps:"
echo "1. Create a GitHub repository (already done: https://github.com/Aishwarya187423/smallcart)"
echo "2. Add the remote origin:"
echo "   git remote add origin https://github.com/Aishwarya187423/smallcart.git"
echo ""
echo "3. Push to GitHub:"
echo "   git push -u origin main"
echo ""
echo "4. In GitHub, go to Settings → Secrets and add:"
echo "   - EC2_HOST: Your EC2 public IP address (13.60.75.103)"
echo "   - SSH_PRIVATE_KEY: Contents of your smallcart.pem file"
echo ""
echo "5. Deploy your AWS infrastructure:"
echo "   python create_aws_infrastructure.py"
echo ""
echo "6. Setup monitoring on EC2:"
echo "   scp -i smallcart.pem setup_monitoring.sh ec2-user@[EC2_IP]:~/"
echo "   ssh -i smallcart.pem ec2-user@[EC2_IP]"
echo "   sudo ./setup_monitoring.sh"
echo ""
echo "7. Push changes to trigger CI/CD deployment:"
echo "   git push origin main"
echo ""
echo "🔗 After deployment, access:"
echo "   • Application: http://[EC2_IP]:5000"
echo "   • Grafana: http://[EC2_IP]:3000 (admin / SmallCart@123)"
echo "   • Prometheus: http://[EC2_IP]:9090"
echo ""
echo "📊 Your application will have full observability with:"
echo "   ✅ Distributed tracing"
echo "   ✅ Custom metrics"  
echo "   ✅ Real-time monitoring"
echo "   ✅ Automated deployments"
echo "   ✅ Error tracking"
echo "   ✅ Performance monitoring"
