from pydantic import BaseModel
from typing import Optional

class User(BaseModel):
    id: int
    email: str
    password: str

class Company(BaseModel):
    id: int
    name: str
    description: Optional[str] = None
    website: Optional[str] = None

class Job(BaseModel):
    id: int
    title: str
    description: str
    company_id: int
