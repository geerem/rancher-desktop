import * as path from 'path';

import type { Config, PlaywrightTestOptions } from '@playwright/test';

const outputDir = path.join(__dirname, '..', 'e2e', 'test-results');
const testDir = path.join(__dirname, '..', '..', 'e2e');
const timeScale = process.env.CI ? 2 : 1;

const config: Config<PlaywrightTestOptions> = {
  testDir,
  outputDir,
  timeout:       600_000 * timeScale,
  globalTimeout: 3_600_000 * timeScale,
  workers:       1,
  reporter:      'list',
};

export default config;
