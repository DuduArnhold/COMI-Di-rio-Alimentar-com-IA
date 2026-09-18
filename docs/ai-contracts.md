# Contrato de IA para parsing de refeições

## Papel da IA

A IA converte uma descrição livre em **candidatos estruturados**. Ela auxilia na interpretação linguística; não decide silenciosamente o registro final nem inventa composição nutricional.

## O que a IA pode fazer

- identificar alimentos e bebidas mencionados;
- decompor preparações explícitas quando houver informação suficiente;
- inferir número, quantidade, unidade e contexto temporal mencionados;
- normalizar sinônimos para termos de busca;
- sinalizar ambiguidade e solicitar esclarecimento;
- propor alternativas de interpretação com justificativa e confiança.

## O que a IA não deve fazer

- ser fonte oficial de calorias ou macronutrientes;
- preencher quantidades ausentes como se fossem fatos;
- salvar refeição, alterar metas ou executar consultas privilegiadas;
- esconder baixa confiança ou correspondência inexistente;
- substituir valores do catálogo por conhecimento paramétrico.

## Contrato de saída

A resposta externa será validada por Zod antes de chegar ao banco. A forma inicial é equivalente a:

```ts
type MealParseResult = {
  schemaVersion: "1";
  mealLabel: string | null;
  occurredAt: string | null;
  items: Array<{
    rawLabel: string;
    interpretedName: string;
    quantity: number | null;
    unit: string | null;
    confidence: number;
    needsClarification: boolean;
    uncertaintyReason: string | null;
    alternatives: Array<{
      interpretedName: string;
      reason: string;
    }>;
  }>;
  clarifyingQuestions: string[];
};
```

Campos nutricionais não pertencem à saída. `matched_food_id` também não vem do LLM: é resultado posterior da engine de resolução contra os alimentos visíveis ao usuário.

## Persistência e estados

Uma `ai_parse_session` é um draft com ciclo de vida:

- `processing`: chamada/validação ainda em curso;
- `needs_review`: itens disponíveis para correção humana;
- `confirmed`: refeição criada explicitamente e ligada à sessão;
- `rejected`: usuário descartou o draft;
- `failed`: parsing falhou, com um código técnico seguro.

A transição para `confirmed` deve ocorrer na mesma transação que cria a refeição e seus snapshots. O banco impede que uma sessão confirmada aponte para uma refeição de outro usuário.

`raw_input` é independente dos itens estruturados e recebe `raw_input_expires_at` em até 30 dias da criação. Um job posterior apagará o texto; ele não apagará necessariamente a sessão ou a refeição confirmada. Prompts completos, respostas livres do provedor e conteúdo desnecessário não devem ser persistidos.

## Regras de incerteza

- `confidence` é um sinal auxiliar de roteamento, não uma decisão ou probabilidade calibrada.
- `needsClarification` exige `uncertaintyReason` legível e acionável.
- Quantidade ou unidade não informada permanece `null`; ambas aparecem juntas ou ambas ficam ausentes.
- Porção padrão sugerida pertence à resolução/revisão e deve ser visível ao usuário.
- Termos ambíguos geram alternativas ou perguntas, sem escolha silenciosa.
- Item sem match confiável fica pendente e não recebe nutrientes inventados.
- Toda interpretação é um draft editável antes de salvar.
- Alternativas ficam em JSON por enquanto, validadas pelo contrato Zod; normalização só será justificada se surgirem consultas relacionais reais.
- Telemetria registra versão e categoria de erro, evitando conteúdo alimentar desnecessário.

## Fronteira com a engine nutricional

Depois do parsing, a engine pesquisa `foods`, escolhe um match somente segundo critérios explícitos, resolve `food_portions`, converte para a unidade canônica e calcula os quatro nutrientes a partir dos valores por 100 g/ml. Na confirmação, grava os totais em `meal_items`; alterações futuras em `foods` não recalculam esses snapshots.
