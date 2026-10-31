import os
import json
from config import settings

firestore_db = None

if settings.DB_TYPE == "firestore":
    try:
        from google.cloud import firestore
        key_path = os.path.join(os.path.dirname(__file__), "serviceAccountKey.json")
        env_key = os.getenv("FIREBASE_SERVICE_ACCOUNT_KEY")
        
        # 1. Eğer yerel serviceAccountKey.json dosyası varsa onu kullan
        if os.path.exists(key_path):
            firestore_db = firestore.Client.from_service_account_json(key_path)
            print("Firestore'a serviceAccountKey.json dosyası ile bağlanıldı. ✅")
        # 2. Eğer Cloud Run ortam değişkeni olarak JSON string verildiyse onu kullan
        elif env_key:
            from google.oauth2 import service_account
            sa_info = json.loads(env_key)
            credentials = service_account.Credentials.from_service_account_info(sa_info)
            firestore_db = firestore.Client(credentials=credentials, project=sa_info.get("project_id"))
            print(f"Firestore'a ortam değişkeni üzerinden ({sa_info.get('project_id')}) bağlanıldı. ✅")
        # 3. Varsayılan GCP kimliği
        elif settings.GCP_PROJECT_ID:
            firestore_db = firestore.Client(project=settings.GCP_PROJECT_ID)
            print(f"Firestore'a GCP Project ID ({settings.GCP_PROJECT_ID}) ile bağlanıldı. ✅")
        else:
            firestore_db = firestore.Client()
            print("Firestore'a varsayılan Google kimliği ile bağlanıldı. ✅")
    except Exception as e:
        print(f"Firestore bağlantı uyarısı: {e}")

def get_firestore():
    return firestore_db
