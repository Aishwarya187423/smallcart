# GitHub Secrets Configuration for SmallCart CI/CD

## Required GitHub Secrets

You need to configure the following secrets in your GitHub repository for the CI/CD pipeline to work:

### 📍 How to Add Secrets in GitHub:
1. Go to your repository: https://github.com/Aishwarya187423/smallcart
2. Click on **Settings** tab
3. In the left sidebar, click **Secrets and variables** → **Actions**
4. Click **New repository secret**
5. Add each secret below

---

## 🔑 Required Secrets:

### 1. **EC2_HOST**
- **Name**: `EC2_HOST`
- **Value**: Your EC2 instance public IP address
- **Example**: `13.60.75.103`
- **How to get**: 
  ```bash
  # After running create_aws_infrastructure.py, check the output or:
  # From AWS Console → EC2 → Instances → Select your instance → Public IPv4 address
  ```

### 2. **SSH_PRIVATE_KEY**
- **Name**: `SSH_PRIVATE_KEY`
- **Value**: Complete contents of your `smallcart.pem` private key file
- **Format**: Include `-----BEGIN RSA PRIVATE KEY-----` and `-----END RSA PRIVATE KEY-----`
- **How to get**:
  ```bash
  # On Windows:
  type smallcart.pem
  
  # On Linux/Mac:
  cat smallcart.pem
  
  # Copy the ENTIRE output including the BEGIN/END lines
  ```

---

## 📋 Step-by-Step Secret Setup:

### Step 1: Get Your EC2 IP Address
After running your infrastructure script:
```bash
python create_aws_infrastructure.py
```

The script will output your EC2 public IP. It will look something like:
```
✅ Instance is now running!
   📍 Public IP: 13.60.75.103
```

### Step 2: Get Your Private Key Content
Open your `smallcart.pem` file and copy the ENTIRE content:
```
-----BEGIN RSA PRIVATE KEY-----
MIIEpAIBAAKCAQEA1234567890abcdef...
[... many lines of encoded key data ...]
...xyz789abc0123456789def0123456789
-----END RSA PRIVATE KEY-----
```

### Step 3: Add Secrets to GitHub

1. **EC2_HOST Secret:**
   - Name: `EC2_HOST`
   - Value: `13.60.75.103` (your actual IP)

2. **SSH_PRIVATE_KEY Secret:**
   - Name: `SSH_PRIVATE_KEY`
   - Value: [Paste the entire content of smallcart.pem file]

---

## 🔍 Verification:

After adding both secrets, you should see them listed in:
```
GitHub → Your Repository → Settings → Secrets and variables → Actions
```

The secrets list should show:
- ✅ `EC2_HOST`
- ✅ `SSH_PRIVATE_KEY`

---

## 🚀 Testing the Pipeline:

Once secrets are configured:

1. **Push code to trigger deployment:**
   ```bash
   git add .
   git commit -m "Test CI/CD deployment"
   git push origin main
   ```

2. **Monitor the deployment:**
   - Go to **Actions** tab in your GitHub repository
   - Watch the deployment workflow run
   - Check for any errors in the logs

3. **Verify deployment success:**
   - Application: `http://13.60.75.103:5000`
   - Grafana: `http://13.60.75.103:3000`

---

## ⚠️ Security Notes:

### Private Key Security:
- ✅ **DO**: Store the private key only in GitHub Secrets
- ❌ **DON'T**: Commit the .pem file to your repository
- ❌ **DON'T**: Share the private key content anywhere else

### IP Address:
- The EC2 IP may change if you stop/start the instance
- Update the `EC2_HOST` secret if the IP changes
- Consider using an Elastic IP for production

---

## 🔧 Troubleshooting:

### Common Issues:

1. **"Permission denied" SSH errors:**
   - Verify `SSH_PRIVATE_KEY` includes BEGIN/END lines
   - Check that the key content is complete and unmodified

2. **"Host not found" errors:**
   - Verify `EC2_HOST` contains only the IP address (no http:// or ports)
   - Ensure EC2 instance is running

3. **Connection timeout:**
   - Check security group allows SSH (port 22) from 0.0.0.0/0
   - Verify EC2 instance is in running state

### Testing SSH Connection Manually:
```bash
# Test if you can connect to your EC2 instance
ssh -i smallcart.pem ec2-user@13.60.75.103

# If this works, your secrets should work too
```

---

## 🎉 Success Indicators:

When everything is configured correctly:

1. **GitHub Actions will show:**
   - ✅ Test job completes successfully
   - ✅ Deploy job connects to EC2
   - ✅ Application deployment succeeds
   - ✅ Health check passes

2. **Your application will be accessible at:**
   - `http://13.60.75.103:5000`

3. **Monitoring will be available at:**
   - `http://13.60.75.103:3000` (Grafana)

That's it! Your CI/CD pipeline will automatically deploy every time you push changes to the main branch.
