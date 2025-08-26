from flask import Flask, render_template, request, redirect, url_for, flash, session, jsonify
from flask_sqlalchemy import SQLAlchemy
from flask_login import LoginManager, UserMixin, login_user, login_required, logout_user, current_user
from werkzeug.security import generate_password_hash, check_password_hash
from datetime import datetime
import os
import logging

# OpenTelemetry imports
try:
    from telemetry_config import instrument_flask_app, log_with_trace
    TELEMETRY_ENABLED = True
except ImportError:
    print("⚠️  OpenTelemetry not available, running without telemetry")
    TELEMETRY_ENABLED = False

app = Flask(__name__)
app.config['SECRET_KEY'] = 'your-secret-key-here'
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///smallcart.db'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/var/log/smallcart.log' if os.path.exists('/var/log/') else 'smallcart.log'),
        logging.StreamHandler()
    ]
)

# Initialize OpenTelemetry if available
if TELEMETRY_ENABLED:
    app = instrument_flask_app(app)
    log_with_trace("🔧 OpenTelemetry instrumentation enabled")
else:
    log_with_trace = lambda msg, level=logging.INFO: logging.log(level, msg)

db = SQLAlchemy(app)
login_manager = LoginManager()
login_manager.init_app(app)
login_manager.login_view = 'login'

# Database Models
class User(UserMixin, db.Model):
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(80), unique=True, nullable=False)
    email = db.Column(db.String(120), unique=True, nullable=False)
    password_hash = db.Column(db.String(128))
    is_admin = db.Column(db.Boolean, default=False)
    orders = db.relationship('Order', backref='user', lazy=True)

class Product(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    description = db.Column(db.Text)
    price = db.Column(db.Float, nullable=False)
    stock = db.Column(db.Integer, default=0)
    image_url = db.Column(db.String(200))
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

class Order(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    total_amount = db.Column(db.Float, nullable=False)
    status = db.Column(db.String(50), default='pending')  # pending, processing, shipped, delivered, cancelled
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    order_items = db.relationship('OrderItem', backref='order', lazy=True, cascade='all, delete-orphan')

class OrderItem(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    order_id = db.Column(db.Integer, db.ForeignKey('order.id'), nullable=False)
    product_id = db.Column(db.Integer, db.ForeignKey('product.id'), nullable=False)
    quantity = db.Column(db.Integer, nullable=False)
    price = db.Column(db.Float, nullable=False)
    product = db.relationship('Product', backref='order_items')

class CartItem(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    product_id = db.Column(db.Integer, db.ForeignKey('product.id'), nullable=False)
    quantity = db.Column(db.Integer, nullable=False, default=1)
    user = db.relationship('User', backref='cart_items')
    product = db.relationship('Product', backref='cart_items')

@login_manager.user_loader
def load_user(user_id):
    return User.query.get(int(user_id))

# Helper function to check if user is admin
def admin_required(f):
    def decorated_function(*args, **kwargs):
        if not current_user.is_authenticated or not current_user.is_admin:
            flash('Admin access required.', 'error')
            return redirect(url_for('login'))
        return f(*args, **kwargs)
    decorated_function.__name__ = f.__name__
    return decorated_function

# Routes
@app.route('/')
def home():
    products = Product.query.all()
    return render_template('home.html', products=products)

@app.route('/register', methods=['GET', 'POST'])
def register():
    if TELEMETRY_ENABLED and 'telemetry' in app.config:
        telemetry = app.config['telemetry']
    
    if request.method == 'POST':
        username = request.form['username']
        email = request.form['email']
        password = request.form['password']
        
        log_with_trace(f"Registration attempt for username: {username}, email: {email}", logging.INFO)
        
        if User.query.filter_by(username=username).first():
            flash('Username already exists.', 'error')
            log_with_trace(f"Registration failed - username exists: {username}", logging.WARNING)
            return redirect(url_for('register'))
        
        if User.query.filter_by(email=email).first():
            flash('Email already exists.', 'error')
            log_with_trace(f"Registration failed - email exists: {email}", logging.WARNING)
            return redirect(url_for('register'))
        
        user = User(
            username=username,
            email=email,
            password_hash=generate_password_hash(password)
        )
        db.session.add(user)
        db.session.commit()
        
        # Increment user registration metric
        if TELEMETRY_ENABLED and 'telemetry' in app.config:
            telemetry['user_registrations'].add(1, {"registration_method": "web"})
        
        log_with_trace(f"User registered successfully: {username}", logging.INFO)
        flash('Registration successful!', 'success')
        return redirect(url_for('login'))
    
    return render_template('register.html')

@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        email_or_username = request.form['email_or_username']
        password = request.form['password']
        
        # Try to find user by email or username
        user = User.query.filter(
            (User.email == email_or_username) | (User.username == email_or_username)
        ).first()
        
        if user and check_password_hash(user.password_hash, password):
            login_user(user)
            flash('Login successful!', 'success')
            if user.is_admin:
                return redirect(url_for('admin_dashboard'))
            return redirect(url_for('home'))
        else:
            flash('Invalid email/username or password.', 'error')
    
    return render_template('login.html')

@app.route('/logout')
@login_required
def logout():
    logout_user()
    flash('You have been logged out.', 'info')
    return redirect(url_for('home'))

@app.route('/add_to_cart/<int:product_id>')
@login_required
def add_to_cart(product_id):
    product = Product.query.get_or_404(product_id)
    
    existing_item = CartItem.query.filter_by(
        user_id=current_user.id,
        product_id=product_id
    ).first()
    
    if existing_item:
        existing_item.quantity += 1
    else:
        cart_item = CartItem(
            user_id=current_user.id,
            product_id=product_id,
            quantity=1
        )
        db.session.add(cart_item)
    
    db.session.commit()
    flash(f'{product.name} added to cart!', 'success')
    return redirect(url_for('home'))

@app.route('/cart')
@login_required
def cart():
    cart_items = CartItem.query.filter_by(user_id=current_user.id).all()
    total = sum(item.quantity * item.product.price for item in cart_items)
    return render_template('cart.html', cart_items=cart_items, total=total)

@app.route('/update_cart/<int:item_id>', methods=['POST'])
@login_required
def update_cart(item_id):
    cart_item = CartItem.query.get_or_404(item_id)
    if cart_item.user_id != current_user.id:
        flash('Unauthorized access.', 'error')
        return redirect(url_for('cart'))
    
    quantity = int(request.form['quantity'])
    if quantity <= 0:
        db.session.delete(cart_item)
    else:
        cart_item.quantity = quantity
    
    db.session.commit()
    flash('Cart updated!', 'success')
    return redirect(url_for('cart'))

@app.route('/remove_from_cart/<int:item_id>')
@login_required
def remove_from_cart(item_id):
    cart_item = CartItem.query.get_or_404(item_id)
    if cart_item.user_id != current_user.id:
        flash('Unauthorized access.', 'error')
        return redirect(url_for('cart'))
    
    db.session.delete(cart_item)
    db.session.commit()
    flash('Item removed from cart!', 'success')
    return redirect(url_for('cart'))

@app.route('/checkout', methods=['POST'])
@login_required
def checkout():
    if TELEMETRY_ENABLED and 'telemetry' in app.config:
        telemetry = app.config['telemetry']
    
    cart_items = CartItem.query.filter_by(user_id=current_user.id).all()
    
    if not cart_items:
        flash('Your cart is empty.', 'error')
        log_with_trace(f"Checkout failed - empty cart for user: {current_user.username}", logging.WARNING)
        return redirect(url_for('cart'))
    
    total_amount = sum(item.quantity * item.product.price for item in cart_items)
    
    log_with_trace(f"Checkout started for user: {current_user.username}, total: ${total_amount:.2f}", logging.INFO)
    
    # Create order
    order = Order(
        user_id=current_user.id,
        total_amount=total_amount,
        status='pending'
    )
    db.session.add(order)
    db.session.flush()
    
    # Create order items
    for cart_item in cart_items:
        order_item = OrderItem(
            order_id=order.id,
            product_id=cart_item.product_id,
            quantity=cart_item.quantity,
            price=cart_item.product.price
        )
        db.session.add(order_item)
        
        # Update product stock
        product = cart_item.product
        product.stock -= cart_item.quantity
    
    # Clear cart
    CartItem.query.filter_by(user_id=current_user.id).delete()
    
    db.session.commit()
    
    # Increment orders metric
    if TELEMETRY_ENABLED and 'telemetry' in app.config:
        telemetry['orders_total'].add(1, {
            "user_type": "admin" if current_user.is_admin else "customer",
            "order_status": "pending"
        })
    
    log_with_trace(f"Order {order.id} placed successfully for user: {current_user.username}", logging.INFO)
    flash('Order placed successfully!', 'success')
    return redirect(url_for('order_history'))

@app.route('/order_history')
@login_required
def order_history():
    orders = Order.query.filter_by(user_id=current_user.id).order_by(Order.created_at.desc()).all()
    return render_template('order_history.html', orders=orders)

# Admin Routes
@app.route('/admin')
@login_required
@admin_required
def admin_dashboard():
    total_products = Product.query.count()
    total_orders = Order.query.count()
    total_users = User.query.filter_by(is_admin=False).count()
    recent_orders = Order.query.order_by(Order.created_at.desc()).limit(5).all()
    
    return render_template('admin/dashboard.html', 
                         total_products=total_products,
                         total_orders=total_orders,
                         total_users=total_users,
                         recent_orders=recent_orders)

@app.route('/admin/products')
@login_required
@admin_required
def admin_products():
    products = Product.query.all()
    return render_template('admin/products.html', products=products)

@app.route('/admin/products/add', methods=['GET', 'POST'])
@login_required
@admin_required
def admin_add_product():
    if request.method == 'POST':
        product = Product(
            name=request.form['name'],
            description=request.form['description'],
            price=float(request.form['price']),
            stock=int(request.form['stock']),
            image_url=request.form.get('image_url', '')
        )
        db.session.add(product)
        db.session.commit()
        flash('Product added successfully!', 'success')
        return redirect(url_for('admin_products'))
    
    return render_template('admin/add_product.html')

@app.route('/admin/products/edit/<int:product_id>', methods=['GET', 'POST'])
@login_required
@admin_required
def admin_edit_product(product_id):
    product = Product.query.get_or_404(product_id)
    
    if request.method == 'POST':
        product.name = request.form['name']
        product.description = request.form['description']
        product.price = float(request.form['price'])
        product.stock = int(request.form['stock'])
        product.image_url = request.form.get('image_url', '')
        
        db.session.commit()
        flash('Product updated successfully!', 'success')
        return redirect(url_for('admin_products'))
    
    return render_template('admin/edit_product.html', product=product)

@app.route('/admin/products/delete/<int:product_id>')
@login_required
@admin_required
def admin_delete_product(product_id):
    product = Product.query.get_or_404(product_id)
    db.session.delete(product)
    db.session.commit()
    flash('Product deleted successfully!', 'success')
    return redirect(url_for('admin_products'))

@app.route('/admin/orders')
@login_required
@admin_required
def admin_orders():
    orders = Order.query.order_by(Order.created_at.desc()).all()
    return render_template('admin/orders.html', orders=orders)

@app.route('/admin/orders/<int:order_id>')
@login_required
@admin_required
def admin_view_order(order_id):
    order = Order.query.get_or_404(order_id)
    return render_template('admin/view_order.html', order=order)

@app.route('/admin/orders/edit/<int:order_id>', methods=['GET', 'POST'])
@login_required
@admin_required
def admin_edit_order(order_id):
    order = Order.query.get_or_404(order_id)
    
    if request.method == 'POST':
        order.status = request.form['status']
        # Update total_amount if provided
        if 'total_amount' in request.form and request.form['total_amount']:
            order.total_amount = float(request.form['total_amount'])
        
        db.session.commit()
        flash('Order updated successfully!', 'success')
        return redirect(url_for('admin_orders'))
    
    return render_template('admin/edit_order.html', order=order)

@app.route('/admin/orders/create', methods=['GET', 'POST'])
@login_required
@admin_required
def admin_create_order():
    if request.method == 'POST':
        user_id = request.form['user_id']
        total_amount = float(request.form['total_amount'])
        status = request.form['status']
        
        # Validate user exists
        user = User.query.get(user_id)
        if not user:
            flash('User not found.', 'error')
            return redirect(url_for('admin_create_order'))
        
        order = Order(
            user_id=user_id,
            total_amount=total_amount,
            status=status
        )
        db.session.add(order)
        db.session.commit()
        
        flash('Order created successfully!', 'success')
        return redirect(url_for('admin_orders'))
    
    users = User.query.filter_by(is_admin=False).all()
    return render_template('admin/create_order.html', users=users)

@app.route('/admin/orders/update_status/<int:order_id>', methods=['POST'])
@login_required
@admin_required
def admin_update_order_status(order_id):
    order = Order.query.get_or_404(order_id)
    order.status = request.form['status']
    db.session.commit()
    flash('Order status updated!', 'success')
    return redirect(url_for('admin_orders'))

@app.route('/admin/orders/delete/<int:order_id>')
@login_required
@admin_required
def admin_delete_order(order_id):
    order = Order.query.get_or_404(order_id)
    db.session.delete(order)
    db.session.commit()
    flash('Order deleted successfully!', 'success')
    return redirect(url_for('admin_orders'))

def create_admin_user():
    """Create default admin user if none exists"""
    admin = User.query.filter_by(is_admin=True).first()
    if not admin:
        admin = User(
            username='admin',
            email='admin@gmail.com',
            password_hash=generate_password_hash('123456'),
            is_admin=True
        )
        db.session.add(admin)
        db.session.commit()
        print("Default admin user created: email='admin@gmail.com', password='123456'")

if __name__ == '__main__':
    with app.app_context():
        db.create_all()
        create_admin_user()
        
        # Add some sample products if none exist
        if Product.query.count() == 0:
            sample_products = [
                Product(name='Laptop', description='High-performance laptop', price=999.99, stock=10, image_url='https://via.placeholder.com/300x200?text=Laptop'),
                Product(name='Smartphone', description='Latest smartphone', price=699.99, stock=15, image_url='https://via.placeholder.com/300x200?text=Smartphone'),
                Product(name='Headphones', description='Wireless noise-cancelling headphones', price=199.99, stock=25, image_url='https://via.placeholder.com/300x200?text=Headphones'),
                Product(name='Tablet', description='10-inch tablet with stylus', price=449.99, stock=20, image_url='https://via.placeholder.com/300x200?text=Tablet'),
            ]
            for product in sample_products:
                db.session.add(product)
            db.session.commit()
            print("Sample products added!")
    
    app.run(debug=True, host='0.0.0.0', port=5000)
