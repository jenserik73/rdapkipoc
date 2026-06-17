FROM fnproject/python:3.12-dev AS build-stage

WORKDIR /function
ADD requirements.txt .
RUN pip install --target /python --no-cache-dir -r requirements.txt

FROM fnproject/python:3.12

WORKDIR /function
COPY --from=build-stage /python /python
COPY *.py .

ENV PYTHONPATH=/python:/function

ENTRYPOINT ["/python/bin/fdk", "/function/func.py", "handler"]
