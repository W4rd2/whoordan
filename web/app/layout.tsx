import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Whoordan",
  description: "Private recovery, sleep, strain, and fitness tracking by W4rd2.",
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
