import json
import os
import sys
from database import get_firestore

def seed_master_products():
    db = get_firestore()
    if not db:
        print("HATA: Firestore bağlantısı kurulamadı. Lütfen serviceAccountKey.json dosyasını eklediğinizden emin olun.")
        sys.exit(1)

    # products_seed.json yolunu bul
    current_dir = os.path.dirname(__file__)
    seed_file = os.path.abspath(os.path.join(current_dir, "..", "backend", "products_seed.json"))
    
    if not os.path.exists(seed_file):
        print(f"HATA: {seed_file} bulunamadı!")
        sys.exit(1)

    with open(seed_file, "r", encoding="utf-8") as f:
        products = json.load(f)

    print(f"Toplam {len(products)} adet ürün Firestore'a aktarılıyor...")

    collection_ref = db.collection("master_products")
    batch = db.batch()
    count = 0
    total_committed = 0

    for idx, p in enumerate(products, start=1):
        # Döküman ID'si olarak 1, 2, 3... veya sap_code kullanabiliriz
        doc_id = str(idx)
        doc_ref = collection_ref.document(doc_id)

        data = {
            "id": idx,
            "product_name": p.get("product_name", ""),
            "category": p.get("category", ""),
            "brand": p.get("brand", ""),
            "barcode": p.get("sap_code", ""),
            "weight_volume": p.get("weight_volume"),
            "unit_price": float(p.get("unit_price") or 0.0),
            "image_url": p.get("image_url") or "",
        }
        batch.set(doc_ref, data)
        count += 1

        # Firestore en fazla 500 işlemi tek batch'te kabul eder
        if count == 450:
            batch.commit()
            total_committed += count
            print(f"Aktarıldı: {total_committed}/{len(products)}...")
            batch = db.batch()
            count = 0

    if count > 0:
        batch.commit()
        total_committed += count

    print(f"Tebrikler! Toplam {total_committed} adet master ürün başarıyla Firestore'a yüklendi! 🎉")

if __name__ == "__main__":
    seed_master_products()

