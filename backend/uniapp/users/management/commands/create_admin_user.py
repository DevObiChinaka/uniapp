from django.core.management.base import BaseCommand
from django.contrib.auth import get_user_model
from django.core.exceptions import ValidationError

User = get_user_model()

class Command(BaseCommand):
    help = 'Create admin or security users from command line'

    def add_arguments(self, parser):
        parser.add_argument('--username', type=str, required=True, help='Username for the user')
        parser.add_argument('--email', type=str, required=True, help='Email for the user')
        parser.add_argument('--first_name', type=str, required=True, help='First name')
        parser.add_argument('--last_name', type=str, required=True, help='Last name')
        parser.add_argument('--password', type=str, required=True, help='Password')
        parser.add_argument('--role', type=str, choices=['admin', 'security'], required=True, 
                          help='Role: admin or security')

    def handle(self, *args, **options):
        username = options['username']
        email = options['email']
        first_name = options['first_name']
        last_name = options['last_name']
        password = options['password']
        role = options['role']

        # Check if user already exists
        if User.objects.filter(username=username).exists():
            self.stdout.write(
                self.style.ERROR(f'User with username "{username}" already exists')
            )
            return

        if User.objects.filter(email=email).exists():
            self.stdout.write(
                self.style.ERROR(f'User with email "{email}" already exists')
            )
            return

        try:
            # Create the user
            user = User.objects.create_user(
                username=username,
                email=email,
                first_name=first_name,
                last_name=last_name,
                password=password,
                role=role,
                university_id='',  # Empty for admin/security users
                campus_tag=None,
                program=None,
                level=None,
            )

            self.stdout.write(
                self.style.SUCCESS(
                    f'Successfully created {role} user: {username} ({first_name} {last_name})'
                )
            )

            # Display user details
            self.stdout.write(f'User ID: {user.id}')
            self.stdout.write(f'Username: {user.username}')
            self.stdout.write(f'Email: {user.email}')
            self.stdout.write(f'Role: {user.role}')
            self.stdout.write(f'Created at: {user.date_joined}')

        except ValidationError as e:
            self.stdout.write(
                self.style.ERROR(f'Validation error: {e}')
            )
        except Exception as e:
            self.stdout.write(
                self.style.ERROR(f'Error creating user: {e}')
            )
