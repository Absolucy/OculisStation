// THIS IS A OCULIS UI FILE
import type { CSSProperties } from 'react';
import { Box } from 'tgui-core/components';
import { capitalizeAll } from 'tgui-core/string';

/** A slime's color as a dot plus its name. Shared by every window in the slime_rancher theme. */
export function SlimeName(props: {
  color: string;
  hex: string;
  suffix?: string;
}) {
  const { color, hex, suffix } = props;

  return (
    <Box className="SlimeRancher__name">
      <Box
        className={`SlimeRancher__swatch${color === 'rainbow' ? ' SlimeRancher__swatch--rainbow' : ''}`}
        style={{ '--slime-color': hex } as CSSProperties}
      />
      <span>
        {capitalizeAll(color)}
        {suffix && ` ${suffix}`}
      </span>
    </Box>
  );
}
