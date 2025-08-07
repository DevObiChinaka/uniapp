#!/usr/bin/env python
import os
import sys
import django

# Add the project directory to Python path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# Set up Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'uniapp.settings')
django.setup()

from users.models import User, Session, Course, Program

def main():
    print("=== Debugging Session Issues ===\n")
    
    # Check user
    student = User.objects.filter(university_id='ADUN001').first()
    if student:
        print(f"Student found: {student.get_full_name()} (ID: {student.id})")
        print(f"University ID: {student.university_id}")
        print(f"Level: {student.level}")
        print(f"Program: {student.program.name if student.program else 'None'}")
        print(f"Campus Tag: {student.campus_tag}")
        print(f"Role: {student.role}\n")
    else:
        print("Student ADUN001 not found!\n")
        return
    
    # Check all sessions
    all_sessions = Session.objects.all()
    print(f"Total sessions in database: {all_sessions.count()}")
    
    if all_sessions.count() == 0:
        print("No sessions found in database! This explains why 'Filtered sessions count: 0'")
        print("\nCreating a test session...")
        
        # Get or create a course for Software Engineering
        se_program = Program.objects.filter(name='Software Engineering').first()
        if se_program:
            # Try to find a course for this program
            course = Course.objects.filter(programs=se_program).first()
            if not course:
                print("No courses found for Software Engineering program")
                print("Available courses:")
                for c in Course.objects.all():
                    print(f"  - {c.name} ({c.code})")
                return
            
            # Get a lecturer
            lecturer = User.objects.filter(role='lecturer').first()
            if not lecturer:
                print("No lecturers found in database")
                return
            
            # Create test session
            test_session = Session.objects.create(
                lecturer=lecturer,
                course=course,
                level='300',  # Match student's level
                is_active=True,
                total_sessions=10,
                pass_threshold=0.7
            )
            print(f"Created test session: {test_session}")
        else:
            print("Software Engineering program not found!")
            return
    
    # List all sessions with details
    print("\n=== All Sessions ===")
    for session in Session.objects.all():
        print(f"Session {session.id}:")
        print(f"  Lecturer: {session.lecturer.username}")
        print(f"  Course: {session.course.name} ({session.course.code})")
        print(f"  Level: {session.level}")
        print(f"  Is Active: {session.is_active}")
        print(f"  Course Programs: {[p.name for p in session.course.programs.all()]}")
        print(f"  Start Time: {session.start_time}")
        print(f"  End Time: {session.end_time}")
        print()
    
    # Check course-program relationships
    print("=== Course-Program Relationships ===")
    se_program = Program.objects.filter(name='Software Engineering').first()
    if se_program:
        courses_for_se = Course.objects.filter(programs=se_program)
        print(f"Courses for Software Engineering program ({courses_for_se.count()}):")
        for course in courses_for_se:
            print(f"  - {course.name} ({course.code}) - Level: {course.level}")
    
    # Check what the filtering logic would find
    print("\n=== Filtering Logic Check ===")
    if student and student.program:
        print(f"Looking for sessions with:")
        print(f"  Student Program: {student.program.name}")
        print(f"  Student Level: {student.level}")
        
        matching_sessions = []
        for session in Session.objects.all():
            course = session.course
            course_programs = [p.name for p in course.programs.all()]
            
            program_match = student.program.name in course_programs
            level_match = (student.level is None or course.level == student.level)
            
            print(f"\n  Session {session.id}:")
            print(f"    Course: {course.name}")
            print(f"    Course Programs: {course_programs}")
            print(f"    Course Level: {course.level}")
            print(f"    Program Match: {program_match}")
            print(f"    Level Match: {level_match}")
            print(f"    Is Active: {session.is_active}")
            
            if program_match and level_match:
                matching_sessions.append(session)
                print(f"    ✓ MATCH!")
            else:
                print(f"    ✗ No match")
        
        print(f"\nTotal matching sessions: {len(matching_sessions)}")

if __name__ == '__main__':
    main()
