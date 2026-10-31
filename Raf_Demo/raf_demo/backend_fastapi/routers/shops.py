from fastapi import APIRouter, HTTPException, Query
from typing import Optional, List
from database import get_firestore

router = APIRouter(prefix="/api/shops", tags=["Shops"])

@router.get("")
async def get_shops(city: Optional[str] = Query(None)):
    db = get_firestore()
    if not db:
        raise HTTPException(status_code=500, detail="Veritabanı bağlantısı hazır değil.")
    
    query = db.collection("merchants")
    if city and city != "Tüm Şehirler":
        query = query.where("city", "==", city)
    
    docs = query.stream()
    shops = []
    for doc in docs:
        d = doc.to_dict()
        shops.append({
            "id": doc.id,
            "name": d.get("shop_name", ""),
            "ownerName": d.get("owner_name", ""),
            "phone": d.get("phone", ""),
            "address": d.get("address", ""),
            "city": d.get("city", ""),
            "rating": d.get("rating", 4.5),
        })
    return shops

@router.get("/{shop_id}")
async def get_shop_detail(shop_id: str):
    db = get_firestore()
    if not db:
        raise HTTPException(status_code=500, detail="Veritabanı bağlantısı hazır değil.")
    
    doc = db.collection("merchants").document(shop_id).get()
    if not doc.exists:
        raise HTTPException(status_code=404, detail="Dükkan bulunamadı.")
    
    d = doc.to_dict()
    return {
        "id": doc.id,
        "name": d.get("shop_name", ""),
        "ownerName": d.get("owner_name", ""),
        "phone": d.get("phone", ""),
        "address": d.get("address", ""),
        "city": d.get("city", ""),
    }

