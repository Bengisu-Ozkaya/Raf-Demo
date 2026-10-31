from fastapi import APIRouter, HTTPException, Depends
from schemas import CustomerProfileUpdateRequest, MerchantProfileUpdateRequest
from security import get_current_customer, get_current_merchant
from database import get_firestore

router = APIRouter(prefix="/api", tags=["Profile"])

@router.put("/customer/profile")
async def update_customer_profile(
    payload: CustomerProfileUpdateRequest,
    customer: dict = Depends(get_current_customer)
):
    db = get_firestore()
    if not db:
        raise HTTPException(status_code=500, detail="Veritabanı bağlantısı hazır değil.")
    
    doc_ref = db.collection("customers").document(customer["customerId"])
    doc = doc_ref.get()
    if not doc.exists:
        raise HTTPException(status_code=404, detail="Kullanıcı bulunamadı.")
    
    updates = {
        "username": payload.username,
        "email": payload.email,
        "phone": payload.phone,
        "city": payload.city,
    }
    if payload.name:
        updates["name"] = payload.name
        
    doc_ref.update(updates)
    return {"success": True, "message": "Profil güncellendi."}

@router.put("/merchant/profile")
async def update_merchant_profile(
    payload: MerchantProfileUpdateRequest,
    merchant: dict = Depends(get_current_merchant)
):
    db = get_firestore()
    if not db:
        raise HTTPException(status_code=500, detail="Veritabanı bağlantısı hazır değil.")
    
    doc_ref = db.collection("merchants").document(merchant["merchantId"])
    doc = doc_ref.get()
    if not doc.exists:
        raise HTTPException(status_code=404, detail="Dükkan bulunamadı.")
    
    updates = {
        "shop_name": payload.shop_name,
        "owner_name": payload.owner_name,
        "phone": payload.phone,
        "city": payload.city,
    }
    if payload.email:
        updates["email"] = payload.email
        
    doc_ref.update(updates)
    return {"success": True, "message": "Profil güncellendi."}

