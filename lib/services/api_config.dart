/// URL raiz da hcf-api: os paths (`/auth/login`, `/rfids/...`) são anexados a ela.
///
/// No servidor publicado o proxy já adiciona o prefixo `/api`; rodando a API
/// localmente, inclua-o (emulador Android: http://10.0.2.2:3000/api).
// TODO: substituir pela URL de produção da hcf-api quando estiver no ar.
const String apiBaseUrl = 'https://api.dev.hcf.cm.utfpr.edu.br';
