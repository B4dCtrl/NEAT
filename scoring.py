def calculate_quality_score(description: str) -> float:
    """
    Calcula o Score de Qualidade de uma vaga com base na clareza
    e completude de sua descrição.

    Esta é uma primeira versão simplificada.
    """
    score = 0

    # Penaliza descrições muito curtas
    if len(description) < 100:
        score -= 20
    # Bonifica descrições de tamanho razoável
    elif len(description) > 500:
        score += 15

    # Verifica a presença de palavras-chave importantes
    keywords = ["responsabilidades", "requisitos", "benefícios", "qualificações"]
    found_keywords = sum(1 for keyword in keywords if keyword in description.lower())

    # Bonifica por cada palavra-chave encontrada
    score += found_keywords * 10

    # Normaliza o score para ficar entre 0 e 100
    return max(0, min(100, score + 50)) # Adiciona 50 para positivar o score inicial

def calculate_company_reputation_score(company_name: str) -> float:
    """
    Calcula o Score de Reputação da Empresa.

    Esta é uma simulação inicial. No futuro, integraremos com APIs
    de avaliação como Glassdoor.
    """
    # Lógica de exemplo: empresas com nomes "Tech" ou "Inova" recebem um bônus
    if "tech" in company_name.lower() or "inova" in company_name.lower():
        return 85.0
    # Empresas com nomes "Consultoria" recebem uma penalidade leve
    elif "consultoria" in company_name.lower():
        return 60.0
    else:
        return 75.0 # Nota padrão

def calculate_final_score(job_description: str, company_name: str) -> float:
    """
    Calcula o Score Final da vaga, combinando o Score de Qualidade
    e o Score de Reputação da Empresa.
    """
    quality = calculate_quality_score(job_description)
    reputation = calculate_company_reputation_score(company_name)

    # Pesos: Qualidade da Vaga (60%), Reputação da Empresa (40%)
    final_score = (quality * 0.6) + (reputation * 0.4)

    return round(final_score, 1)
