#!/usr/bin/env python
import os
import sys
import django

# Add the project directory to Python path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# Set up Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'uniapp.settings')
django.setup()

from users.models import Session

def main():
    print("=== Activating Test Session ===\n")
    
    # Get the first session that matches our student
    session = Session.objects.filter(
        course__programs__name='Software Engineering',
        level='300'
    ).first()
    
    if session:
        print(f"Found session: {session.course.name}")
        print(f"Current is_active: {session.is_active}")
        
        # Activate the session
        session.is_active = True
        session.save()
        
        print(f"Updated is_active: {session.is_active}")
        print("Session activated successfully!")
    else:
        print("No matching session found")

if __name__ == '__main__':
    main()
