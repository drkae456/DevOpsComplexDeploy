from fastapi import FastAPI
from mangum import Mangum
from typing import Optional
import os

# In a real app, you might initialize DB connections, etc. here
# Example: table_name = os.environ.get("DYNAMODB_TABLE")

app = FastAPI(
    title="Serverless FastAPI App",
    description="FastAPI application deployed on AWS Lambda",
    version="1.0.0"
)

@app.get("/")
def read_root():
    return {"message": "Hello from FastAPI running on AWS Lambda!", "status": "success"}

@app.get("/items/{item_id}")
def read_item(item_id: int, q: Optional[str] = None):
    return {"item_id": item_id, "q": q, "source": "lambda"}

@app.get("/health")
def health_check():
    return {"status": "healthy", "service": "fastapi-lambda"}

@app.get("/info")
def get_info():
    return {
        "runtime": "AWS Lambda",
        "framework": "FastAPI",
        "region": os.environ.get("AWS_REGION", "unknown"),
        "function_name": os.environ.get("AWS_LAMBDA_FUNCTION_NAME", "unknown")
    }

# Mangum handler wraps the FastAPI app for Lambda
handler = Mangum(app, lifespan="off")