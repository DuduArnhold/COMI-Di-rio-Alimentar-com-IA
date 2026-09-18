# Arquitetura

## Visão proposta

O projeto usa Next.js com App Router e TypeScript strict. A aplicação é organizada por features na apresentação e por contratos explícitos nas camadas de domínio, serviços e persistência. Supabase fornece PostgreSQL, autenticação e Row Level Security (RLS), mas permanece atrás de repositories.

Esta fundação deliberadamente não cria um framework interno: abstrações serão adicionadas quando um caso de uso real exigir.

## Separação de responsabilidades

| Camada | Responsabilidade |
| --- | --- |
| `app/` | rotas, layouts e composição de páginas |
| `components/` | componentes compartilhados e sem regra de domínio |
| `features/` | UI e comportamento coesos de cada área de produto |
| `types/` | contratos do domínio e schemas Zod compartilhados |
| `services/` | casos de uso, autorização contextual e transações |
| `repositories/` | contratos e implementações de persistência |
| `lib/supabase/` | criação/configuração de clientes Supabase |
| `lib/ai/` | adaptadores de provedores de IA e validação de respostas |
| `lib/nutrition/` | correspondência, conversão e cálculo determinístico |

Componentes React não consultam Supabase diretamente. Server Components e Server Actions chamam services; services dependem de contracts de repository. Isso mantém UI, regras e infraestrutura testáveis separadamente.

## Fluxo UI → service → repository → database

1. A UI valida a entrada de fronteira com Zod e chama um caso de uso.
2. O service aplica regras de domínio, obtém a identidade autenticada e coordena operações.
3. O repository converte operações de domínio em consultas Supabase.
4. PostgreSQL persiste, aplicando constraints, triggers e RLS como defesa obrigatória.
5. Resultados retornam como tipos de domínio; erros esperados são mapeados antes de chegar à UI.

RLS não substitui autorização no service, mas impede que uma falha no filtro de repository exponha outro tenant. O cliente comum nunca usa `service_role`.

## Fluxo do parsing por IA

1. A UI envia texto e contexto mínimo a um endpoint exclusivamente server-side.
2. O service cria uma `ai_parse_session` com retenção explícita do texto bruto e chama um adapter de LLM com saída estruturada.
3. A resposta é validada pelo schema Zod versionado. Respostas inválidas falham de forma controlada.
4. Os candidatos viram `ai_parse_items`, com confiança, motivo da incerteza e alternativas; não recebem nutrientes produzidos pelo modelo.
5. A engine resolve candidatos contra alimentos globais visíveis ou alimentos próprios do usuário e converte a porção para `g`/`ml`.
6. Matches e incertezas compõem um draft em `needs_review`, nunca uma refeição salva automaticamente.
7. Após confirmação explícita, uma transação cria `meals` e snapshots em `meal_items`, liga a sessão à refeição e marca a sessão `confirmed`.

Chaves, prompts internos e chamadas ao provedor nunca são enviados ao cliente. O texto pode conter dados pessoais: `raw_input` tem prazo máximo inicial de 30 dias, deve poder ser apagado antes e não será usado como arquivo permanente.

## Modelo de persistência

- `profiles` estende `auth.users`; autenticação não é duplicada.
- Metas formam intervalos históricos sem sobreposição.
- `foods` suporta fontes externas versionadas e registros privados do usuário no mesmo conceito, com regras claras de ownership.
- Porções domésticas são dependentes do alimento, nunca conversões universais.
- Itens confirmados guardam snapshots imutáveis; catálogo atual e histórico têm ciclos de vida independentes.
- `timezone_at_entry` congela o timezone usado na entrada e `local_date` materializa o agrupamento histórico; uma refeição retroativa pode informar um fuso diferente do perfil atual.
- Templates (`saved_meals`) são separados de consumos (`meals`).
- Drafts de IA são separados de refeições confirmadas e podem expirar independentemente.

## Princípios arquiteturais

- base nutricional estruturada é a fonte de verdade para nutrientes;
- confirmação humana antes da persistência de uma interpretação;
- fronteiras externas validadas com Zod;
- RLS e integridade cross-tenant em todas as tabelas privadas;
- dependências apontam da infraestrutura para contratos de domínio, não para componentes;
- cálculos determinísticos, unidades explícitas e valores `numeric` com precisão definida;
- timestamps em UTC e decisões de calendário no timezone IANA do usuário;
- soft delete apenas quando há necessidade de domínio;
- acessibilidade, telas pequenas e conectividade intermitente consideradas desde o início;
- abstrair somente após surgir uma necessidade concreta.

## Database invariants

As migrations, não apenas os services, protegem os limites essenciais: metas não se sobrepõem; referências a alimentos privados respeitam ownership; snapshots confirmados não são recalculados nem alterados; parsing e template não são consumo; e o calendário histórico de uma refeição não acompanha alterações posteriores no perfil. RLS é validada sob dois contextos `auth.uid()` distintos, nunca apenas como administrador.
