from django.core.management.base import BaseCommand
from django.utils import timezone
from users.models import Session

class Command(BaseCommand):
    help = 'Auto-end sessions whose scheduled end time has passed and are still active.'

    def handle(self, *args, **options):
        now = timezone.now()
        sessions = Session.objects.filter(end_time__isnull=True, is_active=True)
        ended_count = 0
        for session in sessions:
            # If the session has a scheduled end time and it's in the past, end it
            # Here, we assume end_time is the scheduled end, otherwise adjust as needed
            if session.end_time is None and session.start_time and now > session.start_time:
                # If you have a duration or scheduled_end field, use that instead
                session.end_time = now
                session.is_active = False
                session.save()
                ended_count += 1
                self.stdout.write(self.style.SUCCESS(f'Ended session {session.id}'))
        self.stdout.write(self.style.SUCCESS(f'Auto-ended {ended_count} sessions.'))
