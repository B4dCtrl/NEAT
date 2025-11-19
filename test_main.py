from fastapi.testclient import TestClient
from main import app

client = TestClient(app)

def test_read_root_serves_html():
    response = client.get("/")
    assert response.status_code == 200
    assert "text/html" in response.headers['content-type']
    assert "<title>Agregador de Vagas Inteligente</title>" in response.text

def test_list_jobs_empty():
    response = client.get("/api/vagas/")
    assert response.status_code == 200
    assert response.json() == {"data": []}

def test_scrape_jobs_and_list():
    # 1. Dispara o scraping
    response_scrape = client.post("/api/scrape-jobs/")
    assert response_scrape.status_code == 200
    assert "vagas coletadas e pontuadas com sucesso" in response_scrape.json()["message"]

    # 2. Verifica se as vagas foram adicionadas
    response_list = client.get("/api/vagas/")
    assert response_list.status_code == 200

    data = response_list.json()["data"]
    assert len(data) > 0
    assert "score" in data[0]
    assert "title" in data[0]
