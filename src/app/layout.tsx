import type { Metadata, Viewport } from "next";
import { PwaRegistration } from "@/components/pwa-registration";
import "./globals.css";

export const metadata: Metadata = {
  title: "Comi — Diário alimentar",
  description: "Registre refeições de forma simples e conversacional.",
  applicationName: "Comi",
  manifest: "/manifest.webmanifest",
};

export const viewport: Viewport = {
  themeColor: "#217a46",
  width: "device-width",
  initialScale: 1,
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="pt-BR">
      <body>
        {children}
        <PwaRegistration />
      </body>
    </html>
  );
}
