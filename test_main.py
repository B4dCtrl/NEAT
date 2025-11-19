from fastapi.testclient import TestClient
from main import app

client = TestClient(app)

def test_read_root():
    response = client.get("/")
    assert response.status_code == 200
    assert response.json() == {"message": "Olá! Bem-vindo ao nosso agregador de vagas."}

def test_list_jobs_empty():
    # Limpa a base de dados antes de rodar o teste
    app.dependency_overrides.clear()
    response = client.get("/vagas/")
    assert response.status_code == 200
    assert response.json() == {"data": []}

def test_scrape_jobs_and_list():
    # 1. Dispara o scraping
    response_scrape = client.post("/scrape-jobs/")
    assert response_scrape.status_code == 200
    assert "vagas coletadas e pontuadas com sucesso" in response_scrape.json()["message"]

    # 2. Verifica se as vagas foram adicionadas
    response_list = client.get("/vagas/")
    assert response_list.status_code == 200

    data = response_list.json()["data"]
    assert len(data) > 0  # Verifica se a lista não está mais vazia
    assert "score" in data[0] # Verifica se o score foi adicionado
    assert "title" in data[0]
