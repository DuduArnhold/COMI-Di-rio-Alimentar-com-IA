export default function Home() {
  return (
    <main className="mx-auto flex min-h-dvh max-w-md flex-col justify-between px-6 py-10">
      <section className="pt-16">
        <p className="mb-4 font-semibold uppercase tracking-[0.2em] text-green-700">Comi</p>
        <h1 className="text-4xl font-bold leading-tight tracking-tight">Seu diário alimentar, em suas palavras.</h1>
        <p className="mt-5 text-lg leading-8 text-stone-600">
          Uma base simples e confiável para registrar refeições e acompanhar suas metas nutricionais.
        </p>
      </section>
      <aside className="rounded-3xl bg-green-800 p-6 text-green-50 shadow-xl shadow-green-900/10">
        <p className="text-sm font-medium text-green-200">Exemplo de registro</p>
        <p className="mt-2 text-lg leading-7">“Comi dois ovos, um pão francês com queijo e tomei café com leite.”</p>
        <p className="mt-5 border-t border-green-600 pt-4 text-sm text-green-100">Fundação do produto pronta para evoluir.</p>
      </aside>
    </main>
  );
}
