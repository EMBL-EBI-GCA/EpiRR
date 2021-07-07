python manage.py migrate
celery -A epirr worker -l INFO -Q validation