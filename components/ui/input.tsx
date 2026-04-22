import * as React from "react";
import { cn } from "@/lib/utils";

export interface InputProps
  extends React.InputHTMLAttributes<HTMLInputElement> {
  numeric?: boolean;
}

export const Input = React.forwardRef<HTMLInputElement, InputProps>(
  ({ className, numeric, ...props }, ref) => (
    <input
      ref={ref}
      className={cn(
        "min-h-[48px] md:min-h-[40px]",
        "bg-surface-raised text-ink border border-border rounded-sm",
        "px-4 text-base placeholder:text-ink-muted",
        "focus-visible:outline-none focus-visible:border-accent",
        "disabled:opacity-40",
        numeric && "font-mono text-right",
        className,
      )}
      {...props}
    />
  ),
);
Input.displayName = "Input";
