from fastapi import FastAPI, HTTPException, APIRouter
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware
from typing import List, Optional
from models import User
from scraper import scrape_jobs
from scoring import calculate_final_score

app = FastAPI()

# Configuração do CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Router da API
api_router = APIRouter(prefix="/api")

# Simulação de bancos de dados em memória
fake_users_db = []
fake_jobs_db = []

# --- Funções da API ---

@api_router.post("/scrape-jobs/")
def trigger_scrape_jobs():
    """Coleta, pontua e armazena as vagas."""
    EXAMPLE_URL = "https://www.exemplo.com/vagas"
    jobs_data = scrape_jobs(EXAMPLE_URL)

    if not jobs_data:
        raise HTTPException(status_code=500, detail="Não foi possível coletar as vagas.")

    fake_jobs_db.clear()
    for job in jobs_data:
        example_description = "Descrição detalhada da vaga com requisitos, responsabilidades e benefícios."
        job["score"] = calculate_final_score(example_description, job["company"])
        fake_jobs_db.append(job)

    return {"message": f"{len(jobs_data)} vagas coletadas e pontuadas com sucesso!", "data": jobs_data}

@api_router.get("/vagas/")
def list_jobs(cargo: Optional[str] = None, localidade: Optional[str] = None):
    """Lista as vagas com filtros."""
    results = fake_jobs_db
    if cargo:
        results = [job for job in results if cargo.lower() in job["title"].lower()]
    if localidade:
        results = [job for job in results if localidade.lower() in job["location"].lower()]
    return {"data": results}

# --- Evento de Inicialização ---

@app.on_event("startup")
def populate_initial_jobs():
    """Popula o banco de dados com vagas de exemplo na inicialização."""
    print("Servidor iniciando, populando vagas iniciais...")
    trigger_scrape_jobs()
    print("Vagas iniciais populadas com sucesso.")

# --- Montagem da Aplicação ---

app.include_router(api_router)

# Monta o diretório 'static' para servir os arquivos do front-end
app.mount("/", StaticFiles(directory="static", html=True), name="static")
