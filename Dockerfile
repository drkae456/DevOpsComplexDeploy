# Use the official AWS Lambda Python base image
FROM public.ecr.aws/lambda/python:3.9

# Copy the requirements file
COPY pyproject.toml poetry.lock* ./
# Or: COPY requirements.txt ./

# Install dependencies using Poetry
# Ensure you have a poetry.lock file by running `poetry lock`
RUN pip install poetry && poetry config virtualenvs.create false && poetry install --no-root --no-dev
# Or, install using pip:
# RUN pip install -r requirements.txt

# Copy the application source code
COPY ./src/ ${LAMBDA_TASK_ROOT}

# Set the command to run your handler
# The format is <python_module_name>.<handler_object_name>
CMD [ "main.handler" ]