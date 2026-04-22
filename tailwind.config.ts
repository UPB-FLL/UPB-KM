import type { Config } from "tailwindcss";
import forms from "@tailwindcss/forms";

// Tokens mirror design-system.md. Raw hex values stay in :root via
// globals.css; Tailwind consumes them through CSS variables so night mode
// swaps at the --surface layer, not by restyling every utility.
const config: Config = {
  content: [
    "./app/**/*.{ts,tsx}",
    "./components/**/*.{ts,tsx}",
    "./lib/**/*.{ts,tsx}",
  ],
  theme: {
    // No default radii beyond the three we allow.
    borderRadius: {
      none: "0",
      sm: "2px",
      DEFAULT: "2px",
      md: "4px",
      full: "9999px",
    },
    boxShadow: {
      none: "none",
      offset: "2px 2px 0 0 var(--ink)",
    },
    fontFamily: {
      display: ["var(--font-display)", "Georgia", "serif"],
      sans: ["var(--font-body)", "system-ui", "sans-serif"],
      mono: ["var(--font-mono)", "ui-monospace", "monospace"],
    },
    fontSize: {
      xs: ["12px", { lineHeight: "16px" }],
      sm: ["13px", { lineHeight: "18px" }],
      base: ["15px", { lineHeight: "22px" }],
      md: ["17px", { lineHeight: "24px" }],
      lg: ["20px", { lineHeight: "28px" }],
      xl: ["26px", { lineHeight: "32px" }],
      display: ["40px", { lineHeight: "44px" }],
    },
    extend: {
      colors: {
        carbon: "var(--upb-carbon)",
        ash: "var(--upb-ash)",
        iron: "var(--upb-iron)",
        bone: "var(--upb-bone)",
        linen: "var(--upb-linen)",
        chalk: "var(--upb-chalk)",
        dust: "var(--upb-dust)",
        ember: {
          DEFAULT: "var(--upb-ember)",
          ink: "var(--upb-ember-ink)",
        },
        lichen: "var(--upb-lichen)",
        rust: "var(--upb-rust)",
        amber: "var(--upb-amber)",
        slate: "var(--upb-slate)",
        surface: "var(--surface)",
        "surface-raised": "var(--surface-raised)",
        "surface-sunken": "var(--surface-sunken)",
        ink: {
          DEFAULT: "var(--ink)",
          muted: "var(--ink-muted)",
        },
        border: "var(--border)",
        "border-strong": "var(--border-strong)",
        focus: "var(--focus)",
        accent: {
          DEFAULT: "var(--accent)",
          ink: "var(--accent-ink)",
        },
        success: "var(--success)",
        danger: "var(--danger)",
        warning: "var(--warning)",
      },
      spacing: {
        // Enforce the design-system scale.
        "0": "0px",
        "1": "2px",
        "2": "4px",
        "3": "8px",
        "4": "12px",
        "5": "16px",
        "6": "24px",
        "7": "32px",
        "8": "48px",
        "9": "64px",
      },
      transitionDuration: {
        fast: "120ms",
        med: "180ms",
      },
      transitionTimingFunction: {
        upb: "cubic-bezier(.2,.7,.2,1)",
      },
    },
  },
  plugins: [forms({ strategy: "class" })],
};

export default config;
