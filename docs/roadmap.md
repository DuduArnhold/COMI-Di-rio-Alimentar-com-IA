# Roadmap inicial

O roadmap ordena aprendizagem e dependências; não é compromisso de prazo. Cada sprint começa após aprovação das decisões da anterior.

## Sprint 0 — Foundation

- congelar escopo e princípios arquiteturais;
- configurar Next.js, TypeScript strict, Tailwind e shell PWA;
- criar estrutura mínima e documentação;
- definir critérios de qualidade e decisões pendentes do modelo de dados.

## Sprint 1 — Auth/Profile

- definir schema inicial, migrations e políticas RLS de perfil;
- implementar cadastro, login, logout, sessão e recuperação;
- perfil, preferências e metas nutricionais;
- testar isolamento entre usuários.

## Sprint 2 — Nutrition database

- escolher e validar fonte/licença do catálogo;
- definir alimentos, porções, unidades, nutrientes e busca;
- implementar importação versionada e engine determinística;
- cobrir conversões e arredondamento com testes.

## Sprint 3 — Meals/Diary

- criar refeições e itens com snapshot nutricional;
- implementar fluxo manual de revisão e tela Hoje;
- totais diários e navegação por dia;
- garantir consistência transacional e RLS.

## Sprint 4 — Natural Language AI

- selecionar provedor e política de privacidade/custo;
- implementar contrato versionado, Zod e adapter server-side;
- resolver candidatos contra a base nutricional;
- construir revisão, correção e tratamento de incerteza;
- avaliar parsing com conjunto de casos em português.

## Sprint 5 — History/Favorites

- consolidar histórico diário;
- salvar uma composição como favorita e repeti-la;
- adicionar registro opcional de peso;
- revisar acessibilidade e estados vazios/erro.

## Sprint 6 — PWA/Hardening

- revisar estratégia de cache e comportamento offline seguro;
- ícones, instalação, atualização e metadados da PWA;
- observabilidade, performance, segurança e privacidade;
- testes ponta a ponta e preparação de release.
