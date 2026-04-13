import type { ButtonHTMLAttributes, ReactNode } from "react";

export type ButtonVariant =
  | "primary"
  | "secondary"
  | "ghost"
  | "danger";

export type ButtonSize = "sm" | "md" | "lg" | "xl";

export type ButtonProps = ButtonHTMLAttributes<HTMLButtonElement> & {
  variant?: ButtonVariant;
  size?: ButtonSize;
  leadingIcon?: ReactNode;
  trailingIcon?: ReactNode;
  fullWidth?: boolean;
};

function joinClassNames(...parts: Array<string | false | undefined>) {
  return parts.filter(Boolean).join(" ");
}

function ButtonIcon({
  position,
  icon,
}: {
  position: "leading" | "trailing";
  icon: ReactNode;
}) {
  return (
    <span aria-hidden="true" className={`button__icon button__icon--${position}`}>
      {icon}
    </span>
  );
}

export function Button({
  variant = "primary",
  size = "md",
  leadingIcon,
  trailingIcon,
  fullWidth = false,
  className,
  children,
  type = "button",
  ...props
}: ButtonProps) {
  return (
    <button
      {...props}
      className={joinClassNames(
        "button",
        `button--${variant}`,
        `button--${size}`,
        fullWidth && "button--full-width",
        className,
      )}
      type={type}
    >
      {leadingIcon ? <ButtonIcon icon={leadingIcon} position="leading" /> : null}
      <span className="button__label">{children}</span>
      {trailingIcon ? <ButtonIcon icon={trailingIcon} position="trailing" /> : null}
    </button>
  );
}
