# Padrões de código

## TypeScript e validação

- `strict` permanece habilitado; não usar `any`. Prefira `unknown` com narrowing nas fronteiras.
- Modele estados impossíveis com uniões discriminadas e mantenha tipos de domínio explícitos.
- Valide entrada de usuário, variáveis de ambiente, banco e APIs externas com Zod.
- Não use assertions para contornar validação ausente.

## Componentes e features

- Componentes são pequenos, focados e acessíveis; lógica de negócio vive fora da renderização.
- Organize código específico em `features/<nome>`; promova para `components` ou `lib` apenas quando for realmente compartilhado.
- Componentes React não importam clientes Supabase nem executam consultas diretamente.
- Prefira Server Components; use `"use client"` apenas quando interatividade ou API do navegador exigir.

## Nomenclatura

- arquivos e pastas: `kebab-case`;
- componentes, tipos e schemas: `PascalCase` (schemas podem usar sufixo `Schema`);
- funções e variáveis: `camelCase`;
- constantes verdadeiramente globais: `UPPER_SNAKE_CASE`;
- nomes em inglês no código; conteúdo e documentação do produto podem ser em português.

## Erros

- Não exponha mensagens internas, dados pessoais, prompts ou credenciais.
- Represente erros esperados de domínio de forma tipada e traduza-os na fronteira da UI/API.
- Preserve a causa em logs server-side com contexto seguro; nunca ignore exceções silenciosamente.
- Falha de IA ou match nutricional deve resultar em estado recuperável e editável.

## Qualidade

- Cada mudança deve passar por lint, typecheck e build.
- Casos de uso e cálculo nutricional receberão testes unitários; repositories terão testes de integração/RLS.
- Alterações de schema devem aplicar todas as migrations em PostgreSQL/Supabase real e executar `supabase/tests/database_invariants.sql` com dois usuários.
- Todo bug de isolamento deve receber primeiro um caso de regressão que falhe, seguido da correção de constraint, trigger ou policy.
- Testes administrativos servem para preparar fixtures; não substituem assertions sob o papel `authenticated` e `auth.uid()` de usuários distintos.
- Evite dependências sem benefício claro, abstrações especulativas e arquivos genéricos de utilidades.
