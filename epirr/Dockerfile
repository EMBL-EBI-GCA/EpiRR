FROM python:latest
ADD epirr ./epirr
ADD metadata_validation ./epirr
ADD manage.py ./epirr
WORKDIR ./epirr
ADD requirements.txt ./
ADD run_daphne.sh ./
ADD run_celery.sh ./
RUN pip install -r requirements.txt