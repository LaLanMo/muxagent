import type { ReactNode } from "react";

type DesktopWorkbenchFrameProps = {
  center: ReactNode;
  right: ReactNode;
  className?: string;
};

export function DesktopWorkbenchFrame({
  center,
  right,
  className,
}: DesktopWorkbenchFrameProps) {
  return (
    <div className={className ? `desktop-workbench ${className}` : "desktop-workbench"}>
      <div className="desktop-workbench__center">{center}</div>
      <div className="desktop-workbench__divider" />
      <div className="desktop-workbench__right">{right}</div>
    </div>
  );
}
