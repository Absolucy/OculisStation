#!/usr/bin/env node

/**
 * Build script for /tg/station 13 codebase.
 *
 * This script uses Juke Build, read the docs here:
 * https://github.com/stylemistake/juke-build
 */

import fs from 'node:fs';
import Bun from 'bun';
import Juke from './juke/index.js';
import { bun } from './lib/bun';
import {
  DreamDaemon,
  DreamDaemonConsole,
  DreamMaker,
  NamedVersionFile,
} from './lib/byond';
import { downloadFile } from './lib/download';
import { formatDeps } from './lib/helpers';
import { prependDefines } from './lib/tgs';

export const TGS_MODE = process.env.CBT_BUILD_MODE === 'TGS';

export const DME_NAME = 'tgstation';

Juke.chdir('../..', import.meta.url);

const dependencies: Record<string, string> = await Bun.file('dependencies.sh')
  .text()
  .then(formatDeps)
  .catch((err) => {
    Juke.logger.error(
      'Failed to read dependencies.sh, please ensure it exists and is formatted correctly.',
    );
    Juke.logger.error(err);
    throw new Juke.ExitCode(1);
  });

// Canonical path for the cutter exe at this moment
function getCutterPath() {
  const ver = dependencies.CUTTER_VERSION;
  const suffix = process.platform === 'win32' ? '.exe' : '';
  const file_ver = ver.split('.').join('-');

  return `tools/icon_cutter/cache/hypnagogic${file_ver}${suffix}`;
}

const cutter_path = getCutterPath();

const define_params_file = 'data/last_define_params.json'

// Have compilation defines changed since last build?
async function defineParametersChanged(defines: string[]): Promise<boolean> {
  const defines_string = JSON.stringify(defines);
  const params_file = Bun.file(define_params_file);
  if(!await params_file.exists()) {
    await params_file.write(defines_string);
    return true;
  }
  const last_params = await params_file.text();
  await params_file.write(defines_string);
  return last_params !== defines_string;
}

export const DefineParameter = new Juke.Parameter({
  type: 'string[]',
  alias: 'D',
});

export const PortParameter = new Juke.Parameter({
  type: 'string',
  alias: 'p',
});

export const DmVersionParameter = new Juke.Parameter({
  type: 'string',
});

export const CiParameter = new Juke.Parameter({ type: 'boolean' });

export const ForceRecutParameter = new Juke.Parameter({
  type: 'boolean',
  name: 'force-recut',
});

export const SkipIconCutter = new Juke.Parameter({
  type: 'boolean',
  name: 'skip-icon-cutter',
});

export const WarningParameter = new Juke.Parameter({
  type: 'string[]',
  alias: 'W',
});

export const NoWarningParameter = new Juke.Parameter({
  type: 'string[]',
  alias: 'I',
});

export const DmeowWarmupParameter = new Juke.Parameter({
  type: 'string',
  name: 'warmup',
});

export const DmeowWindowParameter = new Juke.Parameter({
  type: 'string',
  name: 'window',
});

export const DmeowCyclesParameter = new Juke.Parameter({
  type: 'string',
  name: 'cycles',
});

export const DmeowThresholdParameter = new Juke.Parameter({
  type: 'string',
  name: 'threshold',
});

export const DmeowSampleRateParameter = new Juke.Parameter({
  type: 'string',
  name: 'sample-rate',
});

// which synthetic workload the round drives: 'burn' (default) or 'gradient'.
// an unrecognised name aborts the round in run_dmeow_burn() rather than falling
// back, so a typo can't quietly measure the wrong thing for four minutes.
export const DmeowLoadParameter = new Juke.Parameter({
  type: 'string',
  name: 'load',
});

// interior edge length of the room, in turfs. a size the map cannot reserve
// aborts the round in atmos_room/start(), so there is no ceiling to enforce here.
export const DmeowRoomSizeParameter = new Juke.Parameter({
  type: 'string',
  name: 'room-size',
});

// runs the equivalence probe instead of the A/B burn round. same build, same
// launch, different world param - the two share everything except which
// question the round answers, so cloning the target would duplicate all of it.
export const DmeowEquivParameter = new Juke.Parameter({
  type: 'boolean',
  name: 'equiv',
});

export const CutterTarget = new Juke.Target({
  onlyWhen: () => {
    const files = Juke.glob(cutter_path);
    return files.length === 0;
  },
  executes: async () => {
    const repo = dependencies.CUTTER_REPO;
    const ver = dependencies.CUTTER_VERSION;
    const suffix = process.platform === 'win32' ? '.exe' : '';
    const download_from = `https://github.com/${repo}/releases/download/${ver}/hypnagogic${suffix}`;
    // We're delaying "comitting" to the final filename here in case downloading fails/is interrupted
    const temp_path = `${cutter_path}_temp`; // yes this means its file extension is .exe_temp I don't really care
    await downloadFile(download_from, temp_path);
    fs.copyFileSync(temp_path, cutter_path);
    fs.rmSync(temp_path);
    if (process.platform !== 'win32') {
      await Juke.exec('chmod', ['+x', cutter_path]);
    }
  },
});

export const IconCutterTarget = new Juke.Target({
  parameters: [ForceRecutParameter],
  dependsOn: () => [CutterTarget],
  inputs: () => {
    const standard_inputs = [
      `icons/**/*.png.toml`,
      `icons/**/*.dmi.toml`,
      `cutter_templates/**/*.toml`,
      // NOVA EDIT ADDITION START - Making it work in our nova master files
      `modular_nova/**/*.png.toml`,
      `modular_nova/**/*.dmi.toml`,
      // NOVA EDIT ADDITION END
      cutter_path,
    ];
    // Alright we're gonna search out any existing toml files and convert
    // them to their matching .dmi or .png file
    const existing_configs = [
      ...Juke.glob(`icons/**/*.png.toml`),
      ...Juke.glob(`icons/**/*.dmi.toml`),
      // NOVA EDIT ADDITION START - Making it work in our nova master files
      ...Juke.glob(`modular_nova/**/*.png.toml`),
      ...Juke.glob(`modular_nova/**/*.dmi.toml`),
      // NOVA EDIT ADDITION END
    ];
    return [
      ...standard_inputs,
      ...existing_configs.map((file) => file.replace('.toml', '')),
    ];
  },
  outputs: ({ get }) => {
    if (get(ForceRecutParameter)) return [];
    const folders = [
      ...Juke.glob(`icons/**/*.png.toml`),
      ...Juke.glob(`icons/**/*.dmi.toml`),
      // NOVA EDIT ADDITION START - Making it work in our nova master files
      ...Juke.glob(`modular_nova/**/*.png.toml`),
      ...Juke.glob(`modular_nova/**/*.dmi.toml`),
      // NOVA EDIT ADDITION END
    ];
    return folders
      .map((file) => file.replace(`.png.toml`, '.dmi'))
      .map((file) => file.replace(`.dmi.toml`, '.png'));
  },
  executes: async () => {
    await Juke.exec(cutter_path, [
      '--dont-wait',
      '--templates',
      'cutter_templates',
      'icons',
      'modular_nova', // NOVA EDIT ADDITION - Making the cutter actually work
    ]);
  },
});

export const DmMapsIncludeTarget = new Juke.Target({
  executes: async () => {
    const folders = [
      ...Juke.glob('_maps/map_files/**/modular_pieces/*.dmm'),
      ...Juke.glob('_maps/RandomRuins/**/*.dmm'),
      ...Juke.glob('_maps/RandomZLevels/**/*.dmm'),
      ...Juke.glob('_maps/shuttles/**/*.dmm'),
      ...Juke.glob('_maps/templates/**/*.dmm'),
    ];
    // NOVA EDIT ADDITION START
    const isNovaTemplate = (file: string) =>
      file.startsWith('_maps/nova/') ||
      file.startsWith('_maps/RandomRuins/SpaceRuins/nova/') ||
      file.startsWith('_maps/RandomRuins/IceRuins/nova/') ||
      file.startsWith('_maps/RandomRuins/LavaRuins/nova/') ||
      file.startsWith('_maps/shuttles/nova/');

    const foldersNova = [];
    for (let i = folders.length - 1; i >= 0; i--) {
      const file = folders[i];
      if (isNovaTemplate(file)) {
        foldersNova.push(file);
        folders.splice(i, 1); // remove from folders
      }
    }

    foldersNova.push(...Juke.glob('_maps/nova/**/*.dmm'));
    // NOVA EDIT ADDITION END

    // OCULIS EDIT ADDITION START
    const isOculisTemplate = (file: string) =>
      file.startsWith('_maps/oculis/') ||
      file.startsWith('_maps/RandomRuins/SpaceRuins/oculis/') ||
      file.startsWith('_maps/RandomRuins/IceRuins/oculis/') ||
      file.startsWith('_maps/RandomRuins/LavaRuins/oculis/') ||
      file.startsWith('_maps/shuttles/oculis/');

    const foldersOculis = [];
    for (let i = folders.length - 1; i >= 0; i--) {
      const file = folders[i];
      if (isOculisTemplate(file)) {
        foldersOculis.push(file);
        folders.splice(i, 1); // remove from folders
      }
    }

    foldersOculis.push(...Juke.glob('_maps/oculis/**/*.dmm'));
    // OCULIS EDIT ADDITION END

    const content = `${folders
      .map((file) => file.replace('_maps/', ''))
      .map((file) => `#include "${file}"`)
      .join('\n')}\n`;
    fs.writeFileSync('_maps/templates.dm', content);
    // NOVA EDIT ADDITION START
    const contentNova = `${foldersNova
      .map((file) => file.replace('_maps/', ''))
      .map((file) => `#include "${file}"`)
      .join('\n')}\n`;
    fs.writeFileSync('_maps/templates_nova.dm', contentNova);
    // NOVA EDIT ADDITION END
    // OCULIS EDIT ADDITION START
    const contentOculis = `${foldersOculis
      .map((file) => file.replace('_maps/', ''))
      .map((file) => `#include "${file}"`)
      .join('\n')}\n`;
    fs.writeFileSync('_maps/templates_oculis.dm', contentOculis);
    // OCULIS EDIT ADDITION END
  },
});

export const BehaviorTreeCompilerTarget = new Juke.Target({
  inputs: [
    'code/**/*.bt.json',
    'code/__DEFINES/**/*.dm',
    'tools/build_bt.py',
  ],
  outputs: () => {
    return Juke.glob('code/**/*.bt.json').map((file) => {
      const rel = file.replace(/\.bt\.json$/, '');
      return `build/behavior_trees/${rel}.bt.compiled.json`;
    });
  },
  executes: async () => {
    const suffix = process.platform == 'win32' ? '.bat' : '';
    await Juke.exec(`tools/bootstrap/python${suffix}`, ['tools/build_bt.py']);
  },
});

export const DmTarget = new Juke.Target({
  parameters: [
    DefineParameter,
    DmVersionParameter,
    WarningParameter,
    NoWarningParameter,
    SkipIconCutter,
  ],
  dependsOn: ({ get }) => [
    get(DefineParameter).includes('ALL_TEMPLATES') && DmMapsIncludeTarget,
    get(DefineParameter).includes('NOVA_TEMPLATES') && DmMapsIncludeTarget, // NOVA EDIT ADDITION
    get(DefineParameter).includes('OCULIS_TEMPLATES') && DmMapsIncludeTarget, // OCULIS EDIT ADDITION
    !get(SkipIconCutter) && IconCutterTarget,
    BehaviorTreeCompilerTarget,
  ],
  inputs: [
    '_maps/map_files/generic/**',
    'maps/**/*.dm',
    'code/**',
    'html/**',
    'icons/**',
    'interface/**',
    'sound/**',
    'tgui/public/tgui.html',
    'modular_nova/**', ///NOVA EDIT ADDITION - Making the CBT work
    'modular_iris/**', /// IRIS ADDITION
    'modular_oculis/**', /// OCULIS EDIT ADDITION
    `${DME_NAME}.dme`,
    NamedVersionFile,
  ],
  outputs: async ({ get }) => {
    if (get(DmVersionParameter) || await defineParametersChanged(get(DefineParameter))) {
      // Always rebuild when a dm version is provided or CLI defines have changed from last run
      return [];
    }
    return [`${DME_NAME}.dmb`, `${DME_NAME}.rsc`];
  },
  executes: async ({ get }) => {
    await DreamMaker(`${DME_NAME}.dme`, {
      defines: ['CBT', ...get(DefineParameter)],
      warningsAsErrors: get(WarningParameter).includes('error'),
      ignoreWarningCodes: get(NoWarningParameter),
      namedDmVersion: get(DmVersionParameter),
    });
  },
});

export const DmTestTarget = new Juke.Target({
  parameters: [
    DefineParameter,
    DmVersionParameter,
    WarningParameter,
    NoWarningParameter,
  ],
  dependsOn: ({ get }) => [
    get(DefineParameter).includes('ALL_MAPS') && DmMapsIncludeTarget,
    IconCutterTarget,
  ],
  executes: async ({ get }) => {
    fs.copyFileSync(`${DME_NAME}.dme`, `${DME_NAME}.test.dme`);
    await DreamMaker(`${DME_NAME}.test.dme`, {
      defines: ['CBT', 'CIBUILDING', ...get(DefineParameter)],
      warningsAsErrors: get(WarningParameter).includes('error'),
      ignoreWarningCodes: get(NoWarningParameter),
      namedDmVersion: get(DmVersionParameter),
    });
    Juke.rm('data/logs/ci', { recursive: true });
    const options = {
      dmbFile: `${DME_NAME}.test.dmb`,
      namedDmVersion: get(DmVersionParameter),
    };
    await DreamDaemon(
      options,
      '-close',
      '-trusted',
      '-verbose',
      '-params',
      'log-directory=ci',
    );
    Juke.rm('*.test.*');
    try {
      const cleanRun = fs.readFileSync('data/logs/ci/clean_run.lk', 'utf-8');
      console.log(cleanRun);
    } catch (err) {
      Juke.logger.error('Test run was not clean, exiting');
      throw new Juke.ExitCode(1);
    }
  },
});

export const AutowikiTarget = new Juke.Target({
  parameters: [
    DefineParameter,
    DmVersionParameter,
    WarningParameter,
    NoWarningParameter,
  ],
  dependsOn: ({ get }) => [
    get(DefineParameter).includes('NOVA_TEMPLATES') && DmMapsIncludeTarget, // NOVA EDIT ADDITION
    get(DefineParameter).includes('OCULIS_TEMPLATES') && DmMapsIncludeTarget, // OCULIS EDIT ADDITION
    IconCutterTarget,
  ],
  outputs: ['data/autowiki_edits.txt'],
  executes: async ({ get }) => {
    fs.copyFileSync(`${DME_NAME}.dme`, `${DME_NAME}.test.dme`);
    await DreamMaker(`${DME_NAME}.test.dme`, {
      defines: ['CBT', 'AUTOWIKI', ...get(DefineParameter)],
      warningsAsErrors: get(WarningParameter).includes('error'),
      ignoreWarningCodes: get(NoWarningParameter),
      namedDmVersion: get(DmVersionParameter),
    });
    Juke.rm('data/autowiki_edits.txt');
    Juke.rm('data/autowiki_files', { recursive: true });
    Juke.rm('data/logs/ci', { recursive: true });

    const options = {
      dmbFile: `${DME_NAME}.test.dmb`,
      namedDmVersion: get(DmVersionParameter),
    };
    await DreamDaemon(
      options,
      '-close',
      '-trusted',
      '-verbose',
      '-params',
      'log-directory=ci',
    );
    Juke.rm('*.test.*');
    if (!fs.existsSync('data/autowiki_edits.txt')) {
      Juke.logger.error('Autowiki did not generate an output, exiting');
      throw new Juke.ExitCode(1);
    }
  },
});

export const BunTarget = new Juke.Target({
  parameters: [CiParameter],
  inputs: ['tgui/**/package.json'],
  executes: () => {
    return bun('./tgui', 'install', '--frozen-lockfile', '--ignore-scripts');
  },
});

export const BiomeInstallTarget = new Juke.Target({
  dependsOn: [BunTarget],
  inputs: ['package.json', 'bun.lock'],
  executes: () => {
    return bun('.', 'install');
  },
});

export const TgFontTarget = new Juke.Target({
  dependsOn: [BunTarget],
  inputs: [
    'tgui/packages/tgfont/**/*.+(js|ts|svg)',
    'tgui/packages/tgfont/package.json',
  ],
  outputs: [
    'tgui/packages/tgfont/dist/tgfont.css',
    'tgui/packages/tgfont/dist/tgfont.woff2',
  ],
  executes: () => bun('./tgui/packages/tgfont', 'tgfont:build'),
});

export const TguiTarget = new Juke.Target({
  dependsOn: [BunTarget, BiomeInstallTarget],
  inputs: [
    'tgui/rspack.config.ts',
    'tgui/**/package.json',
    'tgui/packages/**/*.+(js|cjs|ts|tsx|jsx|scss)',
  ],
  outputs: [
    'tgui/public/tgui.bundle.css',
    'tgui/public/tgui.bundle.js',
    'tgui/public/tgui-panel.bundle.css',
    'tgui/public/tgui-panel.bundle.js',
    'tgui/public/tgui-say.bundle.css',
    'tgui/public/tgui-say.bundle.js',
  ],
  executes: () => bun('./tgui', 'tgui:build'),
});

export const TguiTscTarget = new Juke.Target({
  dependsOn: [BunTarget],
  executes: () => bun('./tgui', 'tgui:tsc'),
});

export const TguiTestTarget = new Juke.Target({
  parameters: [CiParameter],
  dependsOn: [BunTarget],
  executes: () => bun('./tgui', 'tgui:test'),
});

export const BiomeCheckTarget = new Juke.Target({
  dependsOn: [BunTarget, BiomeInstallTarget],
  executes: () => bun('.', 'tgui:lint'),
});

export const TguiLintTarget = new Juke.Target({
  dependsOn: [BunTarget, BiomeCheckTarget, TguiTscTarget],
});

export const TguiDevTarget = new Juke.Target({
  dependsOn: [BunTarget],
  executes: ({ args }) => bun('./tgui', 'tgui:dev', ...args),
});

export const TguiAnalyzeTarget = new Juke.Target({
  dependsOn: [BunTarget],
  executes: () => bun('./tgui', 'tgui:analyze'),
});

export const TestTarget = new Juke.Target({
  dependsOn: [DmTestTarget, TguiTestTarget],
});

export const LintTarget = new Juke.Target({
  dependsOn: [TguiLintTarget],
});

export const BuildTarget = new Juke.Target({
  dependsOn: [TguiTarget, TgFontTarget, DmTarget],
});

export const ServerTarget = new Juke.Target({
  parameters: [DmVersionParameter, PortParameter],
  dependsOn: [BuildTarget],
  executes: async ({ get }) => {
    const port = get(PortParameter) || '1337';
    const options = {
      dmbFile: `${DME_NAME}.dmb`,
      namedDmVersion: get(DmVersionParameter),
    };
    await DreamDaemon(options, port, '-trusted');
  },
});

// world-param keys read by run_dmeow_burn() in code/game/world.dm - keep in
// sync if either side is renamed.
const DMEOW_BURN_WORLD_PARAMS = [
  [DmeowWarmupParameter, 'dmeow-warmup'],
  [DmeowWindowParameter, 'dmeow-window'],
  [DmeowCyclesParameter, 'dmeow-cycles'],
  [DmeowThresholdParameter, 'dmeow-threshold'],
  [DmeowSampleRateParameter, 'dmeow-sample-rate'],
  [DmeowLoadParameter, 'dmeow-load'],
  [DmeowRoomSizeParameter, 'dmeow-room-size'],
] as const;

function newestFileIn(dir: string): string | null {
  if (!fs.existsSync(dir)) {
    return null;
  }
  const entries = fs.readdirSync(dir).map((name) => {
    const fullPath = `${dir}/${name}`;
    return { fullPath, mtimeMs: fs.statSync(fullPath).mtimeMs };
  });
  if (entries.length === 0) {
    return null;
  }
  entries.sort((a, b) => b.mtimeMs - a.mtimeMs);
  return entries[0].fullPath;
}

export const DmeowBurnTarget = new Juke.Target({
  parameters: [
    DefineParameter,
    DmVersionParameter,
    WarningParameter,
    NoWarningParameter,
    DmeowWarmupParameter,
    DmeowWindowParameter,
    DmeowCyclesParameter,
    DmeowThresholdParameter,
    DmeowSampleRateParameter,
    DmeowLoadParameter,
    DmeowRoomSizeParameter,
    DmeowEquivParameter,
  ],
  // mirrors DmTestTarget's dependencies, not BuildTarget's - this compiles its
  // own .burn.dmb (below) rather than reusing the plain tgstation.dmb.
  dependsOn: ({ get }) => [
    get(DefineParameter).includes('ALL_MAPS') && DmMapsIncludeTarget,
    IconCutterTarget,
  ],
  executes: async ({ get }) => {
    if (!fs.existsSync('dmeow.dll') && !fs.existsSync('libdmeow.so')) {
      Juke.logger.error(
        'dmeow.dll (or libdmeow.so) not found next to the .dmb - the round would abort at dmeow_init() anyway, so failing here saves the wait.',
      );
      throw new Juke.ExitCode(1);
    }

    fs.copyFileSync(`${DME_NAME}.dme`, `${DME_NAME}.burn.dme`);
    // runtimestation is maps.txt's dedicated low-memory map, and Lavaland/ruins
    // don't matter to a fire in a sealed room - both just slow the boot down.
    await DreamMaker(`${DME_NAME}.burn.dme`, {
      defines: [
        'CBT',
        'SKIP_LAVALAND',
        'FORCE_MAP="runtimestation"',
        ...get(DefineParameter),
      ],
      warningsAsErrors: get(WarningParameter).includes('error'),
      ignoreWarningCodes: get(NoWarningParameter),
      namedDmVersion: get(DmVersionParameter),
    });

    const equiv = get(DmeowEquivParameter);
    const burnParams: Record<string, string> = equiv
      ? { 'dmeow-equiv': '1', 'log-directory': 'dmeow-equiv' }
      : { 'dmeow-burn': '1', 'log-directory': 'dmeow-burn' };
    // the equivalence probe takes no tunables - it is not a timed measurement,
    // so warmup/window/cycles have nothing to tune.
    if (!equiv) {
      for (const [parameter, worldParamKey] of DMEOW_BURN_WORLD_PARAMS) {
        const value = get(parameter);
        if (value) {
          burnParams[worldParamKey] = value;
        }
      }
    }

    const options = {
      dmbFile: `${DME_NAME}.burn.dmb`,
      namedDmVersion: get(DmVersionParameter),
    };
    await DreamDaemonConsole(
      options,
      '-close',
      '-trusted',
      '-verbose',
      '-params',
      new URLSearchParams(burnParams).toString(),
    );
    Juke.rm('*.burn.*');

    const reportDir = equiv
      ? 'data/logs/dmeow-equiv/dmeow/equiv'
      : 'data/logs/dmeow-burn/dmeow/perf';
    const reportFile = newestFileIn(reportDir);
    if (!reportFile) {
      Juke.logger.error(
        `Round finished but ${reportDir} has no report - check the world log for a DMEOW_${equiv ? 'EQUIV' : 'BURN'}: abort line.`,
      );
      throw new Juke.ExitCode(1);
    }
    Juke.logger.info(`Report: ${reportFile}`);
    Juke.logger.info('Debug log: dmeow_debug.jsonl');
    if (!equiv) {
      Juke.logger.info(
        `Read it with (from byond-re): python scripts/dmeow_perf.py ${reportFile}`,
      );
      // derived from the report's own path rather than newestFileIn, so a round
      // that died before writing its rows can't advertise a previous round's.
      const turfFile = reportFile.replace(
        '/dmeow/perf/',
        '/dmeow/turfs/',
      );
      if (fs.existsSync(turfFile)) {
        Juke.logger.info(
          `Turf rows: python scripts/dmeow_turfs.py ${turfFile} ${reportFile}`,
        );
      }
    }
  },
});

export const AllTarget = new Juke.Target({
  dependsOn: [TestTarget, LintTarget, BuildTarget],
});

export const TguiCleanTarget = new Juke.Target({
  executes: async () => {
    Juke.rm('node_modules', { recursive: true });
    Juke.rm('tgui/public/.tmp', { recursive: true });
    Juke.rm('tgui/public/*.map');
    Juke.rm('tgui/public/*.{chunk,bundle,hot-update}.*');
    Juke.rm('tgui/packages/tgfont/dist', { recursive: true });
    Juke.rm('tgui/node_modules', { recursive: true });
    Juke.rm('tgui/packages/*/node_modules', { recursive: true });
  },
});

export const CleanTarget = new Juke.Target({
  dependsOn: [TguiCleanTarget],
  executes: async () => {
    Juke.rm('*.{dmb,rsc}');
    Juke.rm('_maps/templates.dm');
  },
});

/**
 * Removes more junk at the expense of much slower initial builds.
 */
export const CleanAllTarget = new Juke.Target({
  dependsOn: [CleanTarget],
  executes: async () => {
    Juke.logger.info('Cleaning up data/logs');
    Juke.rm('data/logs', { recursive: true });
  },
});

export const TgsTarget = new Juke.Target({
  dependsOn: [TguiTarget, TgFontTarget],
  executes: async () => {
    Juke.logger.info('Prepending TGS define');
    prependDefines('TGS');
  },
});

Juke.setup({ file: import.meta.url }).then((code) => {
  // We're using the currently available quirk in Juke Build, which
  // prevents it from exiting on Windows, to wait on errors.
  if (code !== 0 && process.argv.includes('--wait-on-error')) {
    Juke.logger.error('Please inspect the error and close the window.');
    return;
  }

  if (TGS_MODE) {
    // workaround for ESBuild process lingering
    // Once https://github.com/privatenumber/esbuild-loader/pull/354 is merged and updated to, this can be removed
    setTimeout(() => process.exit(code), 10000);
  } else {
    process.exit(code);
  }
});

export default TGS_MODE ? TgsTarget : BuildTarget;
