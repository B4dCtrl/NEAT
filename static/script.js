document.addEventListener('DOMContentLoaded', () => {
    const jobsList = document.getElementById('jobs-list');
    const scrapeBtn = document.getElementById('scrape-btn');
    const filterBtn = document.getElementById('filter-btn');
    const cargoFilter = document.getElementById('cargo-filter');
    const localidadeFilter = document.getElementById('localidade-filter');

    // Aponta para a raiz do servidor, já que o JS roda no mesmo domínio
    const API_URL = '/api';

    // Função para exibir as vagas na tela
    const displayJobs = (jobs) => {
        jobsList.innerHTML = ''; // Limpa a lista antes de adicionar os novos cards
        if (jobs.length === 0) {
            jobsList.innerHTML = '<p>Nenhuma vaga encontrada para os filtros aplicados.</p>';
            return;
        }

        jobs.forEach(job => {
            const jobCard = document.createElement('div');
            jobCard.className = 'job-card';
            jobCard.innerHTML = `
                <h2>${job.title}</h2>
                <p><strong>Empresa:</strong> ${job.company}</p>
                <p><strong>Localidade:</strong> ${job.location}</p>
                <div class="score">${job.score}</div>
            `;
            jobsList.appendChild(jobCard);
        });
    };

    // Função para buscar as vagas da API, com filtros
    const fetchJobs = async () => {
        const cargo = cargoFilter.value;
        const localidade = localidadeFilter.value;
        let url = `${API_URL}/vagas/?`;

        if (cargo) {
            url += `cargo=${encodeURIComponent(cargo)}&`;
        }
        if (localidade) {
            url += `localidade=${encodeURIComponent(localidade)}`;
        }

        try {
            const response = await fetch(url);
            const data = await response.json();
            displayJobs(data.data);
        } catch (error) {
            console.error('Erro ao buscar vagas:', error);
            jobsList.innerHTML = '<p>Ocorreu um erro ao carregar as vagas.</p>';
        }
    };

    // Função para disparar o scraping de novas vagas
    const scrapeNewJobs = async () => {
        scrapeBtn.textContent = 'Buscando...';
        scrapeBtn.disabled = true;
        try {
            const response = await fetch(`${API_URL}/scrape-jobs/`, { method: 'POST' });
            const result = await response.json();
            alert(result.message); // Mostra um alerta com a mensagem de sucesso
            fetchJobs(); // Atualiza a lista de vagas
        } catch (error) {
            console.error('Erro ao buscar novas vagas:', error);
            alert('Ocorreu um erro ao buscar novas vagas.');
        } finally {
            scrapeBtn.textContent = 'Buscar Novas Vagas';
            scrapeBtn.disabled = false;
        }
    };

    // Event Listeners
    scrapeBtn.addEventListener('click', scrapeNewJobs);
    filterBtn.addEventListener('click', fetchJobs);

    // Carregamento inicial das vagas
    fetchJobs();
});
