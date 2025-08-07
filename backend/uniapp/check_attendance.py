#!/usr/bin/env python
import os
import sys
import django

# Add the project directory to Python path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# Set up Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'uniapp.settings')
django.setup()

from users.models import User, Attendance

def main():
    print("=== Debugging Attendance Records ===\n")
    
    # Check user
    student = User.objects.filter(university_id='ADUN001').first()
    if student:
        print(f"Student: {student.get_full_name()} (ID: {student.id})")
        print(f"University ID: {student.university_id}")
        print(f"Role: {student.role}\n")
    else:
        print("Student ADUN001 not found!\n")
        return
    
    # Check all attendance records
    all_attendance = Attendance.objects.all()
    print(f"Total attendance records in database: {all_attendance.count()}")
    
    # Check records for this specific student
    student_attendance = Attendance.objects.filter(user=student)
    print(f"Attendance records for student {student.university_id}: {student_attendance.count()}")
    
    if student_attendance.count() > 0:
        print("\nStudent's Attendance Records:")
        for record in student_attendance:
            print(f"  - ID: {record.id}")
            print(f"    Session: {record.session.id if record.session else 'None'}")
            print(f"    Course: {record.session.course.name if record.session and record.session.course else 'None'}")
            print(f"    Timestamp: {record.timestamp}")
            print(f"    Period: {record.period}")
            print(f"    Method: {record.method}")
            print(f"    Face Verified: {record.face_verified}")
            print(f"    Flagged: {record.flagged}")
            print()
    else:
        print("No attendance records found for this student")
        
        # Let's check if there are records for any user
        print("\nAll attendance records in database:")
        for record in all_attendance:
            print(f"  - ID: {record.id}, User: {record.user.university_id if record.user else 'None'}, Method: {record.method}")

if __name__ == '__main__':
    main()
