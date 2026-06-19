import * as React from "react";
import { cn } from "@/lib/utils";

type Variant = "primary" | "secondary" | "ghost" | "destructive";
type Size = "line" | "office";

export interface ButtonProps
  extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: Variant;
  size?: Size;
}

const base =
  "inline-flex items-center justify-center font-medium select-none " +
  "transition-colors duration-fast ease-upb " +
  "disabled:opacity-40 disabled:cursor-not-allowed";

const variants: Record<Variant, string> = {
  primary:
    "bg-accent text-accent-ink border-b border-accent-ink hover:brightness-95",
  secondary:
    "bg-transparent text-ink border border-border-strong hover:bg-surface-raised",
  ghost:
    "bg-transparent text-ink-muted hover:text-ink underline-offset-4 hover:underline",
  destructive:
    "bg-danger text-chalk border-b border-ink hover:brightness-95",
};

const sizes: Record<Size, string> = {
  line: "min-h-[48px] px-6 text-md rounded-md",
  office: "min-h-[32px] px-4 text-sm rounded",
};

export const Button = React.forwardRef<HTMLButtonElement, ButtonProps>(
  ({ className, variant = "primary", size = "line", ...props }, ref) => (
    <button
      ref={ref}
      className={cn(base, variants[variant], sizes[size], className)}
      {...props}
    />
  ),
);
Button.displayName = "Button";
