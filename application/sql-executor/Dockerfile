FROM fnproject/python:3.12-dev AS build-stage

WORKDIR /function
COPY requirements.txt .
RUN pip3 install -r requirements.txt --target /python

FROM fnproject/python:3.12

ARG FUNC_VERSION=dev-ukjent
ENV FUNC_VERSION=${FUNC_VERSION}

WORKDIR /function
COPY --from=build-stage /python /python
COPY func.py .

ENV PYTHONPATH=/python
ENTRYPOINT ["/python/bin/fdk", "/function/func.py", "handler"]
