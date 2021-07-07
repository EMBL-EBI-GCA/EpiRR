python manage.py collectstatic
python manage.py migrate
#daphne --bind 0.0.0.0 --port 8000 epirr.asgi:application
sleep 9999999999