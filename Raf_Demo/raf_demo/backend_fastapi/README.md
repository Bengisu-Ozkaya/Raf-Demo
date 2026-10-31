# Google Cloud Run + Firestore Dağıtım Rehberi

Bu proje, Raf Demo uygulamasının Python (FastAPI) backend servisini Google Cloud Run üzerinde çalıştırmak için hazırlanmıştır.

---

## 1. Gereksinimler

- Google Cloud hesabı ve aktif bir proje (GCP Project ID)
- Bilgisayarınızda kurulu `gcloud` CLI (veya Google Cloud Console Web Shell)

---

## 2. Adım Adım Dağıtım (Deployment)

### Adım 1: Google Cloud Projenizi Seçin
```bash
gcloud config set project [PROJE_ID_NIZ]
```

### Adım 2: Gerekli GCP Servislerini Aktifleştirin
```bash
gcloud services enable run.googleapis.com cloudbuild.googleapis.com firestore.googleapis.com
```

### Adım 3: Cloud Firestore Veritabanını Başlatın (Eğer daha önce oluşturulmadıysa)
```bash
# Ücretsiz kota destekli Firestore Native modunda veritabanı oluşturur:
gcloud firestore databases create --location=europe-west1 --type=firestore-native
```

### Adım 4: Cloud Run'a Tek Komutla Canlıya Alın
`backend_fastapi` dizini içindeyken şu komutu çalıştırın:
```bash
gcloud run deploy raf-backend \
    --source . \
    --region europe-west1 \
    --allow-unauthenticated \
    --set-env-vars DB_TYPE=firestore,GCP_PROJECT_ID=[PROJE_ID_NIZ]
```

Komut tamamlandığında Google Cloud size bir URL verecektir (örneğin: `https://raf-backend-xyz.a.run.app`).

### Adım 5: Mobil Uygulamaya Yeni URL'yi Tanımlayın
Flutter projenizdeki [constants.dart](file:///c:/Users/bngs0/OneDrive/Belgeler/GitHub/Raf-Demo/Raf_Demo/raf_demo/lib/utils/constants.dart) dosyasına gidip:
```dart
const String BASE_URL = 'https://raf-backend-xyz.a.run.app';
```
olarak güncelleyin.

