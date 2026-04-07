import type { ReactNode } from "react";

type DesktopWorkbenchFrameProps = {
  center: ReactNode;
  right: ReactNode;
};

export function DesktopWorkbenchFrame({
  center,
  right,
}: DesktopWorkbenchFrameProps) {
  return (
    <div className="desktop-workbench">
      <div className="desktop-workbench__center">{center}</div>
      <div className="desktop-workbench__divider" />
      <div className="desktop-workbench__right">{right}</div>
    </div>
  );
}
