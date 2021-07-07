from __future__ import absolute_import, unicode_literals
import os
import time
from celery import Celery
from decouple import config

# set the default Django settings module for the 'celery' program.
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'epirr.settings')

app = Celery(
    'metadata_validation_conversion',
    broker=config('BROKER_URL'),
    backend=config('CELERY_BACKED_URL'))

# Using a string here means the worker doesn't have to serialize
# the configuration object to child processes.
# - namespace='CELERY' means all celery-related configuration keys
#   should have a `CELERY_` prefix.
app.config_from_object('django.conf:settings', namespace='CELERY')
app.conf.broker_transport_options = {'visibility_timeout': 43200}

# Load task modules from all registered Django app configs.
app.autodiscover_tasks()


@app.task(bind=True)
def debug_task(self, message):
    print(message)
    print('Request: {0!r}'.format(self.request))
    time.sleep(10)
    return message
