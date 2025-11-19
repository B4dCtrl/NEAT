import httpx
from bs4 import BeautifulSoup
from typing import List, Dict

def scrape_jobs(url: str) -> List[Dict]:
    """
    Função para fazer o scraping de vagas de um determinado site.
    Esta é uma implementação de exemplo e precisará ser adaptada
    para o site específico que vamos usar.
    """
    try:
        response = httpx.get(url)
        response.raise_for_status()  # Lança um erro para respostas com código de erro
        soup = BeautifulSoup(response.text, 'html.parser')
        job_elements = soup.find_all('div', class_='job-listing')
    except (httpx.RequestError, httpx.HTTPStatusError) as exc:
        print(f"Ocorreu um erro na requisição ou o site está indisponível: {exc}")
        # Se a requisição falhar, usamos dados de exemplo para continuar
        job_elements = []

    jobs = []

    if not job_elements:
        # Se não encontrarmos o seletor real ou a requisição falhar, criamos dados de exemplo
        return [
            {"title": "Arquiteto de Software", "company": "Tech Solutions", "location": "Remoto"},
            {"title": "Desenvolvedor Python Pleno", "company": "InovaDev", "location": "São Paulo"},
            {"title": "Analista de Dados Júnior", "company": "Data Insights", "location": "Home Office"},
        ]

    for job_element in job_elements:
        title = job_element.find('h2').text.strip()
        company = job_element.find('p', class_='company').text.strip()
        location = job_element.find('span', class_='location').text.strip()
        jobs.append({"title": title, "company": company, "location": location})

    return jobs

if __name__ == "__main__":
    # URL de exemplo - precisará ser substituída por uma real
    EXAMPLE_URL = "https://www.exemplo.com/vagas"
    scraped_data = scrape_jobs(EXAMPLE_URL)
    print("Vagas coletadas:")
    for job in scraped_data:
        print(job)
