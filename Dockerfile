# Use the official AWS Lambda Python base image
FROM public.ecr.aws/lambda/python:3.9

# Copy the requirements file
COPY requirements.txt ./

# Install dependencies using pip
RUN pip install -r requirements.txt

# Copy the application source code
COPY ./src/ ${LAMBDA_TASK_ROOT}

# Set the command to run your handler
# The format is <python_module_name>.<handler_object_name>
CMD [ "main.handler" ]