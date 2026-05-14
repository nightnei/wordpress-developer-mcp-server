import { execFile } from 'node:child_process';
import { existsSync } from 'node:fs';
import { promisify } from 'node:util';
import type { Browser, BrowserType, LaunchOptions } from 'playwright';
import { resolveNpmCommand } from './node-runtime.js';

const execFileAsync = promisify( execFile );
const DEFAULT_BROWSER_ARGS = [ '--ignore-certificate-errors' ];
// Keep this in sync with package.json. Playwright browser cache revisions are version-specific.
const PLAYWRIGHT_VERSION = '1.60.0';

let browserPromise: Promise< Browser > | undefined;
let cleanupRegistered = false;

async function installPlaywrightChromium() {
	await execFileAsync(
		resolveNpmCommand(),
		[ 'exec', '--yes', `playwright@${ PLAYWRIGHT_VERSION }`, '--', 'install', 'chromium' ],
		{
			env: {
				...process.env,
				CI: process.env.CI ?? '1',
			},
			maxBuffer: 10 * 1024 * 1024,
		}
	);
}

function buildLaunchAttempts( chromium: Pick< BrowserType, 'executablePath' > ): LaunchOptions[] {
	const attempts: LaunchOptions[] = [];
	const executablePath = chromium.executablePath();

	if ( executablePath && existsSync( executablePath ) ) {
		attempts.push( {
			args: DEFAULT_BROWSER_ARGS,
			executablePath,
		} );
	}

	attempts.push( {
		args: DEFAULT_BROWSER_ARGS,
	} );

	return attempts;
}

async function tryLaunchChromium(
	chromium: Pick< BrowserType, 'launch' | 'executablePath' >,
	launchErrors: string[]
) {
	for ( const attempt of buildLaunchAttempts( chromium ) ) {
		const attemptedTarget = attempt.executablePath
			? `executablePath=${ attempt.executablePath }`
			: 'playwright-default';

		try {
			return await chromium.launch( attempt );
		} catch ( error ) {
			launchErrors.push(
				`${ attemptedTarget }: ${ error instanceof Error ? error.message : String( error ) }`
			);
		}
	}
}

function registerCleanup() {
	if ( cleanupRegistered ) {
		return;
	}
	cleanupRegistered = true;

	const cleanup = () => {
		if ( browserPromise ) {
			browserPromise.then( ( browser ) => browser.close().catch( () => undefined ) );
			browserPromise = undefined;
		}
	};

	process.once( 'exit', cleanup );
	process.once( 'SIGINT', cleanup );
	process.once( 'SIGTERM', cleanup );
}

export async function getSharedBrowser() {
	if ( ! browserPromise ) {
		browserPromise = ( async () => {
			const { chromium } = await import( 'playwright' );
			const launchErrors: string[] = [];
			let browser = await tryLaunchChromium( chromium, launchErrors );

			if ( ! browser ) {
				try {
					await installPlaywrightChromium();
					browser = await tryLaunchChromium( chromium, launchErrors );
				} catch ( error ) {
					launchErrors.push(
						`install chromium: ${ error instanceof Error ? error.message : String( error ) }`
					);
				}
			}

			if ( ! browser ) {
				throw new Error(
					'Unable to launch Chromium for site inspection. ' +
						'Run `npx playwright install chromium` and try again. ' +
						`Launch errors: ${ launchErrors.join( ' | ' ) }`
				);
			}

			registerCleanup();
			return browser;
		} )();
	}

	return browserPromise;
}
