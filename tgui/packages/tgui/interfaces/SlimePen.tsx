// THIS IS A OCULIS UI FILE
import type { CSSProperties } from 'react';
import { useState } from 'react';
import { type HsvaColor, hexToHsva, hsvaToHex } from 'tgui-core/color';
import { Box, Button, Icon, Modal, ProgressBar } from 'tgui-core/components';
import { capitalizeAll } from 'tgui-core/string';

import { useBackend } from '../backend';
import { Window } from '../layouts';
import { Hue, SaturationValue } from './ColorPickerModal/Color';
import { HexColorInput } from './ColorPickerModal/TextSetter';
import { SlimeName } from './common/SlimeRancher';

type MutationType = {
  color: string;
  color_hex: string;
};

type Slime = {
  ref: string;
  name: string;
  health: number;
  nutrition: number;
  life_stage: string;
  amount_grown: number;
  color: string;
  color_hex: string;
  possible_mutations: string[];
};

type Data = {
  slimes: Slime[];
  barrier_color: string;
  mutation_types: Record<string, MutationType>;
  width: number;
  height: number;
  soft_capacity: number;
  max_nutrition: number;
  growth_threshold: number;
  default_color: string;
};

function SlimeCard(props: { slime: Slime }) {
  const { data } = useBackend<Data>();
  const { mutation_types, max_nutrition, growth_threshold } = data;
  const { slime } = props;

  return (
    <Box className="SlimeRancher__card SlimePen__slime">
      <Box className="SlimePen__slime-heading">
        <h2>
          <SlimeName color={slime.color} hex={slime.color_hex} suffix="slime" />
        </h2>
        <span className="SlimeRancher__chip">
          {capitalizeAll(slime.life_stage)}
        </span>
      </Box>
      <Box className="SlimePen__meter">
        <span>Health</span>
        <ProgressBar
          value={slime.health}
          maxValue={100}
          ranges={{
            good: [50, Infinity],
            average: [25, 50],
            bad: [-Infinity, 25],
          }}
        >
          {slime.health}%
        </ProgressBar>
      </Box>
      <Box className="SlimePen__meter">
        <span>Nutrition</span>
        <ProgressBar value={slime.nutrition} maxValue={max_nutrition}>
          {slime.nutrition} / {max_nutrition}
        </ProgressBar>
      </Box>
      <Box className="SlimePen__meter">
        <span>Growth</span>
        <ProgressBar value={slime.amount_grown} maxValue={growth_threshold}>
          {slime.amount_grown} / {growth_threshold}
        </ProgressBar>
      </Box>
      {slime.possible_mutations.length > 0 && (
        <Box className="SlimePen__mutations">
          {slime.possible_mutations.map((path) => {
            const mutation = mutation_types[path];
            if (!mutation) {
              return null;
            }
            return (
              <span
                key={path}
                className="SlimeRancher__chip SlimePen__mutation"
                style={{ '--slime-color': mutation.color_hex } as CSSProperties}
              >
                {capitalizeAll(mutation.color)}
              </span>
            );
          })}
        </Box>
      )}
    </Box>
  );
}

/** Picks the fence tint. Built out of the shared color picker pieces so it can live in this window. */
function ColorModal(props: { onClose: () => void }) {
  const { act, data } = useBackend<Data>();
  const { barrier_color, default_color } = data;
  const { onClose } = props;
  const [color, setColor] = useState<HsvaColor>(hexToHsva(barrier_color));

  const handleChange = (params: Partial<HsvaColor>) =>
    setColor((current) => ({ ...current, ...params }));

  return (
    <Modal className="SlimeRancher__card SlimePen__color-modal">
      <h2 className="SlimeRancher__heading">Fence color</h2>
      <div className="react-colorful">
        <SaturationValue hsva={color} onChange={handleChange} />
        <Hue
          hue={color.h}
          onChange={handleChange}
          className="react-colorful__last-control"
        />
      </div>
      <HexColorInput
        fluid
        color={hsvaToHex(color)}
        onChange={(hex) => setColor(hexToHsva(hex))}
      />
      <Box className="SlimePen__color-actions">
        <Button onClick={() => setColor(hexToHsva(default_color))}>
          Reset
        </Button>
        <Button onClick={onClose}>Cancel</Button>
        <Button
          onClick={() => {
            act('set_color', { color: hsvaToHex(color) });
            onClose();
          }}
        >
          Apply
        </Button>
      </Box>
    </Modal>
  );
}

export const SlimePen = () => {
  const { data } = useBackend<Data>();
  const { slimes, barrier_color, width, height, soft_capacity } = data;
  const [pickingColor, setPickingColor] = useState(false);

  return (
    <Window width={720} height={560} theme="slime_rancher">
      {pickingColor && <ColorModal onClose={() => setPickingColor(false)} />}
      <Window.Content scrollable className="SlimePen">
        <Box className="SlimeRancher__card SlimePen__header">
          <span className="SlimeRancher__chip">
            {width} x {height}
          </span>
          <Box className="SlimeRancher__well SlimePen__count">
            <span>Slimes</span>
            <strong>
              {slimes.length} / {soft_capacity}
            </strong>
          </Box>
          <button
            type="button"
            className="SlimeRancher__well SlimePen__fence"
            onClick={() => setPickingColor(true)}
          >
            <span>Fence color</span>
            <span
              className="SlimePen__fence-swatch"
              style={{ '--slime-color': barrier_color } as CSSProperties}
            />
          </button>
        </Box>
        {slimes.length === 0 ? (
          <Box className="SlimeRancher__empty">
            <Icon name="droplet" size={3} />
            <h1>Nothing in here but floor.</h1>
            <p>Slimes inside the fence will show up on this list.</p>
          </Box>
        ) : (
          slimes.map((slime) => <SlimeCard key={slime.ref} slime={slime} />)
        )}
      </Window.Content>
    </Window>
  );
};
