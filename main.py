from fastapi import FastAPI, HTTPException
from typing import List, Optional
from models import User
from scraper import scrape_jobs
from scoring import calculate_final_score

app = FastAPI()

# Simulação de bancos de dados em memória
fake_users_db = []
fake_jobs_db = []

@app.post("/users/", response_model=User)
def create_user(user: User):
    # Lógica para verificar se o usuário já existe seria adicionada aqui
    fake_users_db.append(user)
    return user

@app.get("/users/", response_model=List[User])
def read_users():
    return fake_users_db

@app.post("/login/")
def login(user: User):
    # Lógica de autenticação simplificada
    for u in fake_users_db:
        if u.email == user.email and u.password == user.password:
            return {"message": "Login bem-sucedido!"}
    raise HTTPException(status_code=401, detail="Email ou senha incorretos")

@app.post("/scrape-jobs/")
def trigger_scrape_jobs():
    """
    Endpoint para iniciar o processo de scraping de vagas, calcular seus scores
    e armazená-las em nosso "banco de dados".
    """
    # URL de exemplo - precisará ser substituída por uma real
    EXAMPLE_URL = "https://www.exemplo.com/vagas"
    jobs_data = scrape_jobs(EXAMPLE_URL)

    if not jobs_data:
        raise HTTPException(status_code=500, detail="Não foi possível coletar as vagas.")

    # Limpa o banco de dados antigo e o preenche com as novas vagas
    fake_jobs_db.clear()
    for job in jobs_data:
        example_description = "Descrição detalhada da vaga com requisitos, responsabilidades e benefícios."
        job["score"] = calculate_final_score(example_description, job["company"])
        fake_jobs_db.append(job)

    return {"message": f"{len(jobs_data)} vagas coletadas e pontuadas com sucesso!", "data": jobs_data}

@app.get("/vagas/")
def list_jobs(cargo: Optional[str] = None, localidade: Optional[str] = None):
    """
    Lista as vagas armazenadas, com filtros opcionais por cargo e localidade.
    """
    results = fake_jobs_db

    if cargo:
        results = [job for job in results if cargo.lower() in job["title"].lower()]

    if localidade:
        results = [job for job in results if localidade.lower() in job["location"].lower()]

    return {"data": results}

@app.get("/")
def read_root():
    return {"message": "Olá! Bem-vindo ao nosso agregador de vagas."}
