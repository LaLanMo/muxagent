import { GitBranch } from "lucide-react";

type WorktreeGlyphProps = {
  className?: string;
  size?: number;
  strokeWidth?: number;
};

export function WorktreeGlyph({
  className,
  size = 11,
  strokeWidth = 1.9,
}: WorktreeGlyphProps) {
  return (
    <GitBranch
      aria-hidden="true"
      className={className}
      size={size}
      strokeWidth={strokeWidth}
    />
  );
}
