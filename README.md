# SmallCart - E-commerce Flask Application

A modern e-commerce web application built with Flask, SQLAlchemy, and Bootstrap 5.

**🌐 Live Application**: `http://13.60.75.103:5000`  
**📊 Monitoring Dashboard**: `http://13.60.75.103:3000` (admin / SmallCart@123)  
**🔍 Metrics**: `http://13.60.75.103:9090` (Prometheus)

## Features

### User Features:
- **Authentication**: User registration and login system
- **Product Browsing**: View all available products with images and details
- **Shopping Cart**: Add products to cart, update quantities, remove items
- **Checkout**: Purchase products from cart
- **Order History**: View all past orders with status tracking

### Admin Features:
- **Admin Dashboard**: Overview of products, orders, and users
- **Product Management**: Full CRUD operations on products
- **Order Management**: View and update order status, delete orders
- **Inventory Management**: Track stock levels with visual indicators

### Technical Features:
- **Modern UI**: Bootstrap 5 with responsive design
- **SQLite Database**: Lightweight database for development and production
- **Production Ready**: Configured to run on 0.0.0.0 for deployment
- **Security**: Password hashing, session management, admin protection
- **AWS Deployment**: Deployed on EC2 instance (13.60.75.103) in eu-north-1
- **OpenTelemetry Observability**: Complete monitoring with traces, metrics, and logs
- **CI/CD Pipeline**: Automated deployment via GitHub Actions

## Installation

1. **Clone or download the project files to your desired directory**

2. **Install Python dependencies:**
   ```bash
   pip install -r requirements.txt
   ```

3. **Run the application:**
   ```bash
   python app.py
   ```

4. **Open your browser and navigate to:**
   ```
   http://localhost:5000
   ```

## 🚀 **Production Access**

The application is deployed on AWS EC2:

- **SmallCart Application**: http://13.60.75.103:5000
- **Admin Panel**: Login with `admin@gmail.com` / `123456`
- **Grafana Monitoring**: http://13.60.75.103:3000 (admin / SmallCart@123)
- **Prometheus Metrics**: http://13.60.75.103:9090

### AWS Infrastructure Details:
- **Instance ID**: i-081c9990cdbd7573c
- **Region**: eu-north-1 (Stockholm)
- **Instance Type**: t3.micro
- **VPC**: vpc-06111db1e5a53d537
- **Security Group**: sg-0c578a5a84aab36ea
- **SSH Access**: `ssh -i smallcart.pem ec2-user@13.60.75.103`

## Default Admin Account

The application automatically creates a default admin account:
- **Email:** `admin@gmail.com`
- **Password:** `123456`

You can login using either email or username.

## Database Setup

The application automatically:
- Creates the SQLite database (`smallcart.db`)
- Sets up all required tables
- Creates the default admin user
- Adds sample products for testing

## Project Structure

```
smallcart/
├── app.py                          # Main application file
├── requirements.txt                # Python dependencies
├── README.md                      # This file
├── smallcart.db                   # SQLite database (created automatically)
└── templates/
    ├── base.html                  # Base template with navigation
    ├── home.html                  # Homepage with product grid
    ├── login.html                 # User login page
    ├── register.html              # User registration page
    ├── cart.html                  # Shopping cart page
    ├── order_history.html         # User order history
    └── admin/
        ├── dashboard.html         # Admin dashboard
        ├── products.html          # Product management
        ├── add_product.html       # Add new product
        ├── edit_product.html      # Edit existing product
        └── orders.html            # Order management
```

## Usage

### For Customers:
1. **Register** a new account or use existing credentials
2. **Browse products** on the homepage
3. **Add items to cart** by clicking "Add to Cart"
4. **View cart** and update quantities as needed
5. **Checkout** to place your order
6. **Track orders** in your order history

### For Administrators:
1. **Login** with admin credentials
2. **Access Admin Panel** from the navigation menu
3. **Manage Products**: Add, edit, or delete products
4. **Manage Orders**: Update order status or delete orders
5. **Monitor Dashboard**: View statistics and recent activity

## Database Models

- **User**: Stores user accounts and admin privileges
- **Product**: Product information, pricing, and inventory
- **Order**: Order records with status tracking
- **OrderItem**: Individual items within orders
- **CartItem**: Shopping cart contents per user

## Order Status Types

- **Pending**: Order placed, awaiting processing
- **Processing**: Order being prepared
- **Shipped**: Order dispatched
- **Delivered**: Order completed successfully
- **Cancelled**: Order cancelled

## Production Deployment

The application is currently deployed on AWS EC2 at `http://13.60.75.103:5000` and configured for production with:

### 🔧 **Current Deployment:**
- **EC2 Instance**: i-081c9990cdbd7573c (t3.micro in eu-north-1)
- **Public IP**: 13.60.75.103
- **Application URL**: http://13.60.75.103:5000
- **SSH Access**: `ssh -i smallcart.pem ec2-user@13.60.75.103`

### 📊 **Monitoring Stack:**
- **Grafana**: http://13.60.75.103:3000 (admin / SmallCart@123)
- **Prometheus**: http://13.60.75.103:9090
- **OpenTelemetry**: Automatic tracing and metrics collection
- **CI/CD**: GitHub Actions pipeline for automated deployment

### 🔒 **Security Configuration:**
1. **Change the secret key** in `app.py` for security ✅ Done
2. **Use environment variables** for sensitive configuration ✅ Done
3. **Production WSGI server** deployment ✅ Done
4. **Proper logging** and error handling ✅ Done
5. **Security groups** configured for necessary ports ✅ Done

## Customization

### Adding New Features:
- Modify `app.py` for new routes and functionality
- Add new templates in the `templates/` directory
- Update database models as needed
- Extend the admin panel for new management features

### Styling:
- The application uses Bootstrap 5 CDN
- Custom styles can be added to the `<style>` section in `base.html`
- Images are handled via URL references

## Security Features

- Password hashing using Werkzeug
- Session-based authentication with Flask-Login
- Admin-only route protection
- CSRF protection through POST requests
- Input validation and sanitization

## Sample Data

The application includes sample products for testing:
- Laptop ($999.99)
- Smartphone ($699.99)
- Headphones ($199.99)
- Tablet ($449.99)

## Support

This is a demonstration e-commerce application. For production use, consider additional features like:
- Payment gateway integration
- Email notifications
- Advanced user roles
- Product categories
- Search and filtering
- Reviews and ratings
- Inventory alerts
