#!/usr/bin/env python
import os
import sys
import django

# Add the Django project directory to Python path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

# Set up Django environment
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'uniapp.settings')
django.setup()

from users.models import User

def check_security_user():
    print("=== Security User Details ===")
    try:
        # Find security user with username 'sec123'
        security_user = User.objects.filter(username='sec123', role='security').first()
        
        if security_user:
            print(f"✅ Found security user:")
            print(f"   ID: {security_user.id}")
            print(f"   Username: {security_user.username}")
            print(f"   Name: {security_user.get_full_name() or security_user.first_name or 'N/A'}")
            print(f"   First Name: {security_user.first_name or 'N/A'}")
            print(f"   Last Name: {security_user.last_name or 'N/A'}")
            print(f"   Role: {security_user.role}")
            print(f"   University ID: {security_user.university_id or 'N/A'}")
            print(f"   Email: {security_user.email or 'N/A'}")
            print(f"   Is Active: {security_user.is_active}")
            print(f"   Date Joined: {security_user.date_joined}")
        else:
            print("❌ No security user found with username 'sec123'")
            
            # Check if there are any security users at all
            all_security = User.objects.filter(role='security')
            if all_security.exists():
                print(f"\n📋 Found {all_security.count()} security user(s):")
                for user in all_security:
                    print(f"   - ID: {user.id}, Username: {user.username}, Name: {user.get_full_name() or user.first_name or 'N/A'}")
            else:
                print("\n❌ No security users found in the database")
                
    except Exception as e:
        print(f"❌ Error checking security user: {e}")

if __name__ == "__main__":
    check_security_user()
