# SmallCart Deployment Checklist

## 🎯 **Final Deployment Steps**

Follow this checklist to complete your SmallCart deployment:

---

## ✅ **Phase 1: AWS Infrastructure Setup**

### 1.1 Deploy AWS Infrastructure
```bash
cd e:\aishwarya_thesis_2
python create_aws_infrastructure.py
```

**Expected Output:**
- ✅ VPC created/found
- ✅ Security Group configured (ports 22, 80, 443, 5000, 3000, 9090)
- ✅ EC2 instance launched
- 📍 **Note down the Public IP address**

### 1.2 Setup Monitoring Stack
```bash
# Copy monitoring script to EC2
scp -i smallcart.pem setup_monitoring.sh ec2-user@13.60.75.103:~/

# Connect to EC2 and run setup
ssh -i smallcart.pem ec2-user@13.60.75.103
sudo ./setup_monitoring.sh
```

**Expected Output:**
- ✅ Grafana installed and running on port 3000
- ✅ Tempo installed for distributed tracing
- ✅ Prometheus installed for metrics
- ✅ OTEL Collector configured

---

## ✅ **Phase 2: GitHub Configuration**

### 2.1 Configure Repository Secrets
Go to: https://github.com/Aishwarya187423/smallcart/settings/secrets/actions

**Add these secrets:**
- `EC2_HOST`: Your EC2 public IP (e.g., `13.60.75.103`)
- `SSH_PRIVATE_KEY`: Complete content of `smallcart.pem` file

### 2.2 Verify Repository Files
Ensure these files are in your repository:
- ✅ `app.py`
- ✅ `telemetry_config.py`
- ✅ `requirements.txt`
- ✅ `deploy.sh`
- ✅ `.github/workflows/deploy.yml`
- ✅ `templates/` folder with all HTML files

---

## ✅ **Phase 3: Deploy Application**

### 3.1 Push Code to GitHub
```bash
git add .
git commit -m "Deploy SmallCart with OpenTelemetry monitoring"
git push origin main
```

### 3.2 Monitor Deployment
1. Go to: https://github.com/Aishwarya187423/smallcart/actions
2. Click on the latest workflow run
3. Monitor the deployment progress:
   - ✅ Test phase (runs pytest)
   - ✅ Deploy phase (deploys to EC2)
   - ✅ Health check (verifies app is running)

---

## 🌐 **Phase 4: Access Your Application**

### 4.1 Application URLs
Your actual application URLs with IP `13.60.75.103`:

| Service | URL | Credentials |
|---------|-----|-------------|
| **SmallCart App** | `http://13.60.75.103:5000` | User: Any email / Pass: Any<br>Admin: admin@gmail.com / 123456 |
| **Grafana Dashboard** | `http://13.60.75.103:3000` | admin / SmallCart@123 |
| **Prometheus** | `http://13.60.75.103:9090` | No auth |

### 4.2 Test Application Features
- ✅ User registration/login
- ✅ Browse products
- ✅ Add to cart
- ✅ Place orders
- ✅ Admin panel access
- ✅ Admin product management
- ✅ Admin order management

---

## 📊 **Phase 5: Monitoring and Observability**

### 5.1 Grafana Dashboards
1. Access Grafana at `http://13.60.75.103:3000`
2. Login with `admin / SmallCart@123`
3. Navigate to dashboards to see:
   - HTTP request metrics
   - Database query performance
   - Application traces
   - Error rates and response times

### 5.2 Application Metrics
Your SmallCart app automatically exports:
- **HTTP Metrics**: Request count, duration, status codes
- **Database Metrics**: Query performance, connection pool
- **Custom Metrics**: User actions, cart operations
- **Traces**: End-to-end request tracing

---

## 🔧 **Troubleshooting Guide**

### Issue: CI/CD Pipeline Fails
**Check:**
- ✅ GitHub secrets are correctly configured
- ✅ EC2 instance is running
- ✅ Security group allows SSH (port 22)

**Debug Commands:**
```bash
# Test SSH connection manually
ssh -i smallcart.pem ec2-user@13.60.75.103

# Check EC2 instance status
aws ec2 describe-instances --instance-ids i-081c9990cdbd7573c
```

### Issue: Application Not Accessible
**Check:**
- ✅ EC2 instance security group allows port 5000
- ✅ Application is running: `sudo systemctl status smallcart`
- ✅ Logs: `sudo journalctl -u smallcart -f`

### Issue: Monitoring Not Working
**Check:**
- ✅ Grafana service: `sudo systemctl status grafana-server`
- ✅ Tempo service: `sudo systemctl status tempo`
- ✅ OTEL Collector: `sudo systemctl status otel-collector`

---

## 🎉 **Success Criteria**

Your deployment is successful when:

1. **✅ GitHub Actions Pipeline**: All jobs pass (Test → Deploy → Health Check)

2. **✅ Application Access**: 
   - SmallCart loads at `http://13.60.75.103:5000`
   - User can register, login, add products to cart
   - Admin can access admin panel with credentials

3. **✅ Monitoring Stack**:
   - Grafana accessible at `http://13.60.75.103:3000`
   - Dashboards show application metrics
   - Traces visible in Grafana/Tempo

4. **✅ Continuous Deployment**:
   - Code changes pushed to GitHub automatically deploy
   - Health checks prevent broken deployments

---

## 📞 **Next Steps**

After successful deployment:

1. **📱 Mobile Testing**: Test responsive design on mobile devices
2. **🔒 SSL Setup**: Configure HTTPS with Let's Encrypt (optional)
3. **📈 Scaling**: Consider load balancing for high traffic
4. **🗄️ Database**: Migrate to RDS for production workloads
5. **🔐 Security**: Enable additional security groups restrictions

---

**🎊 Congratulations! Your SmallCart application is now live with enterprise-grade monitoring and CI/CD!**
