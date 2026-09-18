# Especificação do produto — MVP

## Problema

Registrar alimentação costuma exigir buscas, formulários e decisões repetitivas. Essa fricção reduz a consistência do diário e, consequentemente, a utilidade do acompanhamento nutricional.

## Proposta do produto

O **Comi** é um diário alimentar mobile-first no qual a pessoa descreve uma refeição em linguagem natural, revisa a interpretação estruturada e só então a salva. A IA reduz o trabalho de entrada; uma base nutricional estruturada mantém calorias e macronutrientes consistentes.

## Fluxo principal

1. A pessoa digita o que comeu e, opcionalmente, informa o contexto da refeição.
2. A IA converte a descrição em candidatos a alimentos, porções e unidades.
3. A engine nutricional busca correspondências confiáveis na base estruturada.
4. A interface apresenta itens, quantidades, calorias e macronutrientes, destacando incertezas.
5. A pessoa confirma ou corrige os dados.
6. O sistema salva a refeição no dia selecionado e atualiza os totais diários.

## Escopo do MVP

- login e cadastro;
- perfil básico e metas diárias de calorias e macronutrientes;
- tela Hoje e histórico por dia;
- registro de refeição por texto em linguagem natural;
- parsing por IA, cálculo nutricional por dados estruturados e revisão antes de salvar;
- refeições, itens de refeição, favoritos e repetição de refeição;
- registro opcional de peso;
- experiência PWA mobile-first.

## Não-escopo

Não fazem parte da V1: reconhecimento por foto, código de barras, receitas, jejum, gamificação, mascote, desafios, planejamento semanal ou alimentar e integrações com Garmin, Google Fit, Apple Health ou outros wearables.

## Critério central de produto

**A IA interpreta alimentos e quantidades; ela não é a fonte oficial dos valores nutricionais.** Quando não houver correspondência confiável, o produto deve pedir confirmação ou dados adicionais em vez de apresentar precisão falsa.
