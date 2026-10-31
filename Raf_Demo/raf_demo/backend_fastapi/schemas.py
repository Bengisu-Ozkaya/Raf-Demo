from pydantic import BaseModel, EmailStr, Field
from typing import Optional, List, Any

# Customer Schemas
class CustomerRegisterRequest(BaseModel):
    username: str
    email: str
    phone: str
    password: str
    city: str

class CustomerLoginRequest(BaseModel):
    loginIdentifier: str
    password: str

class CustomerProfileUpdateRequest(BaseModel):
    name: Optional[str] = None
    username: str
    email: str
    phone: str
    city: str

# Merchant Schemas
class MerchantRegisterRequest(BaseModel):
    shop_name: str
    owner_name: str
    phone: str
    password: str
    city: str

class MerchantLoginRequest(BaseModel):
    identifier: str
    password: str

class MerchantProfileUpdateRequest(BaseModel):
    shop_name: str
    owner_name: str
    phone: str
    city: str
    email: Optional[str] = None

# Product Schemas
class AddProductRequest(BaseModel):
    master_product_id: int
    price: float
    stock: int

class UpdateProductRequest(BaseModel):
    price: Optional[float] = None
    stock: Optional[int] = None

class AddProductsBatchRequest(BaseModel):
    products: List[dict]

# Package Schemas
class CreatePackageRequest(BaseModel):
    name: str
    description: Optional[str] = None
    package_size: str = "Standart Paket"
    total_price: float
    stock: int
    items: List[dict] = []

class UpdatePackageRequest(BaseModel):
    name: Optional[str] = None
    total_price: Optional[float] = None
    stock: Optional[int] = None

