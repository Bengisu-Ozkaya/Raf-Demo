from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from datetime import datetime

from routers import auth, shops, products, packages, profile
from config import settings

app = FastAPI(
    title="Raf Demo Backend API",
    description="Python FastAPI + Google Cloud Run Backend Servisi",
    version="2.0.0"
)

# CORS ayarları
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Router'ları ekle
app.include_router(auth.router)
app.include_router(shops.router)
app.include_router(products.router)
app.include_router(packages.router)
app.include_router(profile.router)

@app.get("/")
async def root():
    return {
        "success": True,
        "message": "Raf Demo FastAPI Backend başarıyla çalışıyor! 🚀",
        "timestamp": datetime.utcnow().isoformat(),
        "database": settings.DB_TYPE
    }

@app.get("/api/health")
async def health_check():
    return {"status": "ok", "service": "raf-demo-fastapi"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=settings.PORT, reload=True)

