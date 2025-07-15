#!/usr/bin/env python
"""
Test script to verify admin registration fix
"""
import os
import sys
import django

# Add the project directory to Python path
sys.path.append('/path/to/project')

# Setup Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'uniapp.settings')
django.setup()

from users.serializers import UserRegistrationSerializer

# Test data that was failing before
test_data = {
    'first_name': 'Chidera',
    'last_name': 'Chinaka',
    'role': 'admin',
    'password': 'Admin123!',
    'email': 'chiderachinaka06@gmail.com',
    'university_id': None,
    'username': 'Admin01',
    'campus_tag': None,
    'program': None
}

# Test the serializer
serializer = UserRegistrationSerializer(data=test_data)
if serializer.is_valid():
    print("✅ SUCCESS: Admin registration data is now valid!")
    print(f"Validated data: {serializer.validated_data}")
else:
    print("❌ FAILED: Serializer validation errors:")
    print(serializer.errors)

# Test student registration to ensure it still works
student_data = {
    'first_name': 'Test',
    'last_name': 'Student',
    'role': 'student',
    'password': 'Student123!',
    'email': 'test.student@example.com',
    'university_id': 'STU001',
    'username': None,
    'campus_tag': 'on-campus',
    'program': 'Computer Science'
}

student_serializer = UserRegistrationSerializer(data=student_data)
if student_serializer.is_valid():
    print("✅ SUCCESS: Student registration still works!")
else:
    print("❌ WARNING: Student registration broken:")
    print(student_serializer.errors)
