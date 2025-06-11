from fastapi import FastAPI
from mangum import Mangum
import os

# In a real app, you might initialize DB connections, etc. here
# Example: table_name = os.environ.get("DYNAMODB_TABLE")

app = FastAPI(title="MyServerlessApp")

@app.get("/")
def read_root():
    return {"message": "Hello from FastAPI in a Lambda container!"}

@app.get("/items/{item_id}")
def read_item(item_id: int, q: str | None = None):
    return {"item_id": item_id, "q": q}

# Mangum handler wraps the FastAPI app for Lambda
handler = Mangum(app, lifespan="off")