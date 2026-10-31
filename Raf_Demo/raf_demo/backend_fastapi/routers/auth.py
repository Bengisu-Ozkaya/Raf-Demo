from fastapi import APIRouter, HTTPException, status
from schemas import (
    CustomerRegisterRequest, CustomerLoginRequest,
    MerchantRegisterRequest, MerchantLoginRequest
)
from security import verify_password, get_password_hash, create_access_token
from database import get_firestore

router = APIRouter(prefix="/api", tags=["Auth"])

@router.post("/customer/register")
async def register_customer(payload: CustomerRegisterRequest):
    db = get_firestore()
    if not db:
        raise HTTPException(status_code=500, detail="Veritabanı bağlantısı hazır değil.")
    
    # Kullanıcı adı veya e-posta kontrolü
    existing_users = db.collection("customers").where("username", "==", payload.username).limit(1).stream()
    if any(existing_users):
        raise HTTPException(status_code=400, detail="Bu kullanıcı adı zaten alınmış.")

    password_hash = get_password_hash(payload.password)
    user_data = {
        "username": payload.username,
        "email": payload.email,
        "phone": payload.phone,
        "city": payload.city,
        "password_hash": password_hash,
    }
    
    doc_ref = db.collection("customers").document()
    doc_ref.set(user_data)
    
    return {"success": True, "message": "Müşteri kaydı başarıyla tamamlandı."}

@router.post("/customer/login")
async def login_customer(payload: CustomerLoginRequest):
    db = get_firestore()
    if not db:
        raise HTTPException(status_code=500, detail="Veritabanı bağlantısı hazır değil.")
    
    # Kullanıcı adı veya e-posta ile arama
    users = list(db.collection("customers").where("username", "==", payload.loginIdentifier).limit(1).stream())
    if not users:
        users = list(db.collection("customers").where("email", "==", payload.loginIdentifier).limit(1).stream())
    
    if not users:
        raise HTTPException(status_code=401, detail="Geçersiz kullanıcı adı veya şifre.")
    
    user_doc = users[0]
    user_dict = user_doc.to_dict()
    
    if not verify_password(payload.password, user_dict.get("password_hash", "")):
        raise HTTPException(status_code=401, detail="Geçersiz kullanıcı adı veya şifre.")
    
    token = create_access_token({
        "customerId": user_doc.id,
        "username": user_dict.get("username"),
        "role": "customer"
    })
    
    return {
        "success": True,
        "token": token,
        "user": {
            "id": user_doc.id,
            "username": user_dict.get("username"),
            "email": user_dict.get("email"),
            "phone": user_dict.get("phone"),
            "city": user_dict.get("city"),
        }
    }

@router.post("/merchant/register")
async def register_merchant(payload: MerchantRegisterRequest):
    db = get_firestore()
    if not db:
        raise HTTPException(status_code=500, detail="Veritabanı bağlantısı hazır değil.")
    
    existing = list(db.collection("merchants").where("phone", "==", payload.phone).limit(1).stream())
    if existing:
        raise HTTPException(status_code=400, detail="Bu telefon numarasına ait bir dükkan zaten kayıtlı.")

    import time
    numeric_id = int(time.time() * 1000) % 2147483647
    password_hash = get_password_hash(payload.password)
    merchant_data = {
        "id": numeric_id,
        "shop_name": payload.shop_name,
        "owner_name": payload.owner_name,
        "phone": payload.phone,
        "city": payload.city,
        "password_hash": password_hash,
    }
    
    doc_ref = db.collection("merchants").document(str(numeric_id))
    doc_ref.set(merchant_data)
    
    return {"success": True, "message": "Esnaf/Dükkan kaydı başarıyla tamamlandı.", "shopId": numeric_id}

@router.post("/merchant/login")
async def login_merchant(payload: MerchantLoginRequest):
    db = get_firestore()
    if not db:
        raise HTTPException(status_code=500, detail="Veritabanı bağlantısı hazır değil.")
    
    merchants = list(db.collection("merchants").where("phone", "==", payload.identifier).limit(1).stream())
    if not merchants:
        merchants = list(db.collection("merchants").where("shop_name", "==", payload.identifier).limit(1).stream())
    
    if not merchants:
        raise HTTPException(status_code=401, detail="Geçersiz dükkan bilgisi veya şifre.")
    
    merchant_doc = merchants[0]
    merchant_dict = merchant_doc.to_dict()
    
    if not verify_password(payload.password, merchant_dict.get("password_hash", "")):
        raise HTTPException(status_code=401, detail="Geçersiz dükkan bilgisi veya şifre.")
    
    shop_id = merchant_dict.get("id")
    if shop_id is None:
        import zlib
        shop_id = zlib.crc32(merchant_doc.id.encode('utf-8')) & 0x7FFFFFFF
        try:
            merchant_doc.reference.update({"id": shop_id})
        except Exception:
            pass
    
    token = create_access_token({
        "merchantId": str(shop_id),
        "merchantDocId": merchant_doc.id,
        "shopName": merchant_dict.get("shop_name"),
        "role": "merchant"
    })
    
    return {
        "success": True,
        "token": token,
        "shopId": shop_id,
        "shopName": merchant_dict.get("shop_name"),
        "city": merchant_dict.get("city"),
    }

