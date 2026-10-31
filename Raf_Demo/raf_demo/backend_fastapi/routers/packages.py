from fastapi import APIRouter, HTTPException, Depends, Query
from typing import Optional, List
from schemas import CreatePackageRequest, UpdatePackageRequest
from security import get_current_merchant
from database import get_firestore

router = APIRouter(prefix="/api/packages", tags=["Packages"])

@router.get("")
async def get_packages(shopId: Optional[str] = Query(None)):
    db = get_firestore()
    if not db:
        raise HTTPException(status_code=500, detail="Veritabanı bağlantısı hazır değil.")
    
    query = db.collection("shop_packages")
    if shopId:
        query = query.where("shop_id", "==", shopId)
    
    docs = query.stream()
    packages = []
    for doc in docs:
        d = doc.to_dict()
        pkg_id = d.get("id")
        if pkg_id is None:
            try:
                pkg_id = int(doc.id)
            except ValueError:
                pkg_id = abs(hash(doc.id)) % 2147483647
        shop_id = d.get("shop_id")
        if shop_id is not None:
            try:
                shop_id = int(shop_id)
            except (ValueError, TypeError):
                shop_id = abs(hash(str(shop_id))) % 2147483647
        packages.append({
            "id": pkg_id,
            "shop_id": shop_id,
            "name": d.get("name"),
            "description": d.get("description", ""),
            "package_size": d.get("package_size", "Standart Paket"),
            "total_price": float(d.get("total_price", 0.0)),
            "stock": int(d.get("stock", 0)),
            "items": d.get("items", []),
        })
    return {"success": True, "data": packages}

@router.post("")
async def create_package(
    payload: CreatePackageRequest,
    merchant: dict = Depends(get_current_merchant)
):
    db = get_firestore()
    if not db:
        raise HTTPException(status_code=500, detail="Veritabanı bağlantısı hazır değil.")
    
    import time
    numeric_id = int(time.time() * 1000) % 2147483647
    
    package_data = {
        "id": numeric_id,
        "shop_id": merchant["merchantId"],
        "name": payload.name,
        "description": payload.description,
        "package_size": payload.package_size,
        "total_price": payload.total_price,
        "stock": payload.stock,
        "items": payload.items,
    }
    
    doc_ref = db.collection("shop_packages").document(str(numeric_id))
    doc_ref.set(package_data)
    
    return {"success": True, "packageId": numeric_id}

@router.put("/{package_id}")
async def update_package(
    package_id: str,
    payload: UpdatePackageRequest,
    merchant: dict = Depends(get_current_merchant)
):
    db = get_firestore()
    if not db:
        raise HTTPException(status_code=500, detail="Veritabanı bağlantısı hazır değil.")
    
    doc_ref = db.collection("shop_packages").document(package_id)
    doc = doc_ref.get()
    if not doc.exists:
        raise HTTPException(status_code=404, detail="Paket bulunamadı.")
    
    if str(doc.to_dict().get("shop_id")) != str(merchant["merchantId"]):
        raise HTTPException(status_code=403, detail="Bu paketi güncelleme yetkiniz yok.")
    
    updates = {}
    if payload.name is not None:
        updates["name"] = payload.name
    if payload.total_price is not None:
        updates["total_price"] = payload.total_price
    if payload.stock is not None:
        updates["stock"] = payload.stock
        
    if updates:
        doc_ref.update(updates)
        
    return {"success": True, "message": "Paket başarıyla güncellendi."}

@router.delete("/{package_id}")
async def delete_package(
    package_id: str,
    merchant: dict = Depends(get_current_merchant)
):
    db = get_firestore()
    if not db:
        raise HTTPException(status_code=500, detail="Veritabanı bağlantısı hazır değil.")
    
    doc_ref = db.collection("shop_packages").document(package_id)
    doc = doc_ref.get()
    if not doc.exists:
        raise HTTPException(status_code=404, detail="Paket bulunamadı.")
    
    if str(doc.to_dict().get("shop_id")) != str(merchant["merchantId"]):
        raise HTTPException(status_code=403, detail="Bu paketi silme yetkiniz yok.")
    
    doc_ref.delete()
    return {"success": True, "message": "Paket silindi."}

