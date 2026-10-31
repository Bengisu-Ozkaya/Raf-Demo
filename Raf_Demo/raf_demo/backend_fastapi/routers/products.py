from fastapi import APIRouter, HTTPException, Depends, Query
from typing import Optional, List
from schemas import AddProductRequest, UpdateProductRequest, AddProductsBatchRequest
from security import get_current_merchant
from database import get_firestore

router = APIRouter(prefix="/api", tags=["Products"])

@router.get("/master-products")
async def get_master_products(
    category: Optional[str] = Query(None),
    search: Optional[str] = Query(None)
):
    db = get_firestore()
    if not db:
        raise HTTPException(status_code=500, detail="Veritabanı bağlantısı hazır değil.")
    
    query = db.collection("master_products")
    if category and category != "Tümü":
        query = query.where("category", "==", category)
    
    docs = query.stream()
    products = []
    for doc in docs:
        d = doc.to_dict()
        name = d.get("product_name", "")
        if search and search.lower() not in name.lower():
            continue
        products.append({
            "id": doc.id,
            "product_name": name,
            "category": d.get("category", ""),
            "brand": d.get("brand", ""),
            "barcode": d.get("barcode", ""),
            "image_url": d.get("image_url", ""),
        })
    
    return {"success": True, "data": products}

@router.get("/products")
async def get_shop_products(shopId: Optional[str] = Query(None)):
    db = get_firestore()
    if not db:
        raise HTTPException(status_code=500, detail="Veritabanı bağlantısı hazır değil.")
    
    query = db.collection("shop_products")
    if shopId:
        query = query.where("shop_id", "==", shopId)
    
    docs = query.stream()
    products = []
    for doc in docs:
        d = doc.to_dict()
        products.append({
            "id": doc.id,
            "shopId": d.get("shop_id"),
            "master_product_id": d.get("master_product_id"),
            "name": d.get("name", "Ürün"),
            "brand": d.get("brand", ""),
            "category": d.get("category", ""),
            "price": float(d.get("price", 0.0)),
            "stock": int(d.get("stock", 0)),
            "imageUrl": d.get("image_url", ""),
        })
    return products

@router.post("/products")
async def add_product(
    payload: AddProductRequest,
    merchant: dict = Depends(get_current_merchant)
):
    db = get_firestore()
    if not db:
        raise HTTPException(status_code=500, detail="Veritabanı bağlantısı hazır değil.")
    
    merchant_id = merchant["merchantId"]
    
    # Master ürün bilgilerini çek
    master_doc = db.collection("master_products").document(str(payload.master_product_id)).get()
    master_data = master_doc.to_dict() if master_doc.exists else {}
    
    shop_product_data = {
        "shop_id": merchant_id,
        "master_product_id": payload.master_product_id,
        "name": master_data.get("product_name", "Ürün"),
        "brand": master_data.get("brand", ""),
        "category": master_data.get("category", ""),
        "image_url": master_data.get("image_url", ""),
        "price": payload.price,
        "stock": payload.stock,
    }
    
    doc_ref = db.collection("shop_products").document()
    doc_ref.set(shop_product_data)
    
    return {"success": True, "message": "Ürün başarıyla dükkana eklendi.", "id": doc_ref.id}

@router.post("/products/batch")
async def add_products_batch(
    payload: AddProductsBatchRequest,
    merchant: dict = Depends(get_current_merchant)
):
    db = get_firestore()
    if not db:
        raise HTTPException(status_code=500, detail="Veritabanı bağlantısı hazır değil.")
    
    merchant_id = merchant["merchantId"]
    batch = db.batch()
    
    for item in payload.products:
        doc_ref = db.collection("shop_products").document()
        item_data = {
            "shop_id": merchant_id,
            "master_product_id": item.get("master_product_id"),
            "name": item.get("name", "Ürün"),
            "brand": item.get("brand", ""),
            "category": item.get("category", ""),
            "image_url": item.get("imageUrl", item.get("image_url", "")),
            "price": float(item.get("price", 0.0)),
            "stock": int(item.get("stock", 0)),
        }
        batch.set(doc_ref, item_data)
    
    batch.commit()
    return {"success": True, "count": len(payload.products)}

@router.put("/products/{shop_product_id}")
async def update_product(
    shop_product_id: str,
    payload: UpdateProductRequest,
    merchant: dict = Depends(get_current_merchant)
):
    db = get_firestore()
    if not db:
        raise HTTPException(status_code=500, detail="Veritabanı bağlantısı hazır değil.")
    
    doc_ref = db.collection("shop_products").document(shop_product_id)
    doc = doc_ref.get()
    if not doc.exists:
        raise HTTPException(status_code=404, detail="Ürün bulunamadı.")
    
    if doc.to_dict().get("shop_id") != merchant["merchantId"]:
        raise HTTPException(status_code=403, detail="Bu ürünü güncelleme yetkiniz yok.")
    
    updates = {}
    if payload.price is not None:
        updates["price"] = payload.price
    if payload.stock is not None:
        updates["stock"] = payload.stock
    
    if updates:
        doc_ref.update(updates)
        
    return {"success": True, "message": "Ürün başarıyla güncellendi."}

@router.delete("/products/{shop_product_id}")
async def delete_product(
    shop_product_id: str,
    merchant: dict = Depends(get_current_merchant)
):
    db = get_firestore()
    if not db:
        raise HTTPException(status_code=500, detail="Veritabanı bağlantısı hazır değil.")
    
    doc_ref = db.collection("shop_products").document(shop_product_id)
    doc = doc_ref.get()
    if not doc.exists:
        raise HTTPException(status_code=404, detail="Ürün bulunamadı.")
    
    if doc.to_dict().get("shop_id") != merchant["merchantId"]:
        raise HTTPException(status_code=403, detail="Bu ürünü silme yetkiniz yok.")
    
    doc_ref.delete()
    return {"success": True, "message": "Ürün silindi."}

