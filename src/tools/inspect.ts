import { getSharedBrowser } from '../lib/browser.js';
import { formatCliFailure, runStudioCli } from '../lib/studio-cli.js';
import { SITE_PATH_DESCRIPTION } from '../lib/constants.js';
import type { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import type { Page } from 'playwright';
import type { StudioSiteStatus } from '../lib/studio-cli-types.js';
import { z } from 'zod';

const VIEWPORTS = {
	desktop: { width: 1440, height: 900 },
	mobile: { width: 390, height: 844 },
} as const;

type ViewportName = keyof typeof VIEWPORTS;

function normalizeRoute( route: string | undefined ) {
	if ( ! route?.trim() ) {
		return '/';
	}

	const trimmed = route.trim();
	if ( /^https?:\/\//i.test( trimmed ) || trimmed.startsWith( '//' ) ) {
		throw new Error( 'route must be site-relative, for example "/" or "/about/".' );
	}

	return trimmed.startsWith( '/' ) ? trimmed : `/${ trimmed }`;
}

function buildPageUrl( siteUrl: string, route: string ) {
	return new URL( route, siteUrl ).toString();
}

async function getSiteStatus( path: string ) {
	const res = await runStudioCli( [ 'site', 'status', '--path', path, '--format=json' ] );
	if ( res.exitCode !== 0 ) {
		throw new Error( formatCliFailure( 'studio site status', res ) );
	}

	return JSON.parse( res.stdout.trim() ) as StudioSiteStatus;
}

async function getRunningSiteUrl( path: string ) {
	let status = await getSiteStatus( path );
	if ( status.siteUrl && status.autoLoginUrl ) {
		return status.siteUrl;
	}

	const start = await runStudioCli( [ 'site', 'start', '--path', path, '--skip-browser' ] );
	if ( start.exitCode !== 0 ) {
		throw new Error( formatCliFailure( 'studio site start', start ) );
	}

	status = await getSiteStatus( path );
	if ( ! status.siteUrl ) {
		throw new Error( 'Studio did not return a site URL after starting the site.' );
	}

	return status.siteUrl;
}

async function waitForImages( page: Page, fullPage: boolean ) {
	await page.evaluate( async ( shouldScroll ) => {
		const delay = ( ms: number ) => new Promise< void >( ( resolve ) => setTimeout( resolve, ms ) );

		if ( shouldScroll ) {
			const viewportHeight = window.innerHeight;
			for ( let y = 0; y < document.body.scrollHeight; y += viewportHeight ) {
				window.scrollTo( 0, y );
				await delay( 80 );
			}
			window.scrollTo( 0, 0 );
		}

		const pendingImages = Array.from( document.images ).filter( ( img ) => {
			if ( img.complete ) {
				return false;
			}
			if ( shouldScroll ) {
				return true;
			}
			const rect = img.getBoundingClientRect();
			return rect.bottom > 0 && rect.top < window.innerHeight;
		} );

		const timeout = new Promise< void >( ( resolve ) => setTimeout( resolve, 4000 ) );
		const allImages = Promise.all(
			pendingImages.map(
				( img ) =>
					new Promise< void >( ( resolve ) => {
						img.addEventListener( 'load', () => resolve(), { once: true } );
						img.addEventListener( 'error', () => resolve(), { once: true } );
					} )
			)
		);
		await Promise.race( [ allImages, timeout ] );
	}, fullPage );
}

async function collectAriaSnapshot( page: Page ) {
	try {
		return ( await page.locator( 'body' ).ariaSnapshot( { timeout: 5000 } ) ).slice( 0, 12000 );
	} catch ( error ) {
		return `Unable to collect accessibility snapshot: ${
			error instanceof Error ? error.message : String( error )
		}`;
	}
}

async function collectPageSummary( page: Page ) {
	return page.evaluate( () => {
		const cleanText = ( value: string | null | undefined ) =>
			( value ?? '' ).replace( /\s+/g, ' ' ).trim();

		const visible = ( element: Element ) => {
			const rect = element.getBoundingClientRect();
			const style = window.getComputedStyle( element );
			return (
				rect.width > 0 &&
				rect.height > 0 &&
				style.display !== 'none' &&
				style.visibility !== 'hidden' &&
				Number( style.opacity ) !== 0
			);
		};

		const collectText = ( selector: string, limit: number ) =>
			Array.from( document.querySelectorAll( selector ) )
				.filter( visible )
				.slice( 0, limit )
				.map( ( element ) => cleanText( element.textContent ) )
				.filter( Boolean );

		const headings = Array.from( document.querySelectorAll( 'h1,h2,h3,h4' ) )
			.filter( visible )
			.slice( 0, 40 )
			.map( ( element ) => ( {
				level: element.tagName.toLowerCase(),
				text: cleanText( element.textContent ),
			} ) )
			.filter( ( heading ) => heading.text );

		const links = Array.from( document.querySelectorAll( 'a[href]' ) )
			.filter( visible )
			.slice( 0, 60 )
			.map( ( element ) => ( {
				text: cleanText( element.textContent || element.getAttribute( 'aria-label' ) ),
				href: element.getAttribute( 'href' ),
			} ) )
			.filter( ( link ) => link.text || link.href );

		const buttons = Array.from(
			document.querySelectorAll( 'button,[role="button"],input[type=submit]' )
		)
			.filter( visible )
			.slice( 0, 30 )
			.map( ( element ) => cleanText( element.textContent || element.getAttribute( 'value' ) ) )
			.filter( Boolean );

		const images = Array.from( document.images )
			.filter( visible )
			.slice( 0, 60 )
			.map( ( image ) => ( {
				src: image.currentSrc || image.src,
				alt: image.alt,
				width: image.naturalWidth,
				height: image.naturalHeight,
				displayedWidth: Math.round( image.getBoundingClientRect().width ),
				displayedHeight: Math.round( image.getBoundingClientRect().height ),
				loaded: image.complete && image.naturalWidth > 0,
			} ) );

		const overflowingElements = Array.from( document.body.querySelectorAll( '*' ) )
			.filter( visible )
			.filter( ( element ) => element.getBoundingClientRect().right > window.innerWidth + 1 )
			.slice( 0, 20 )
			.map( ( element ) => ( {
				tag: element.tagName.toLowerCase(),
				id: element.id || undefined,
				className: typeof element.className === 'string' ? element.className.slice( 0, 120 ) : '',
				text: cleanText( element.textContent ).slice( 0, 120 ),
				right: Math.round( element.getBoundingClientRect().right ),
			} ) );

		const emptySections = Array.from(
			document.querySelectorAll( 'section,main,article,header,footer' )
		)
			.filter( visible )
			.filter( ( element ) => cleanText( element.textContent ).length < 12 )
			.slice( 0, 20 )
			.map( ( element ) => ( {
				tag: element.tagName.toLowerCase(),
				id: element.id || undefined,
				className: typeof element.className === 'string' ? element.className.slice( 0, 120 ) : '',
			} ) );

		return {
			title: document.title,
			lang: document.documentElement.lang || undefined,
			bodyClasses: document.body.className,
			textSamples: collectText( 'main p, main li, article p, article li, .wp-site-blocks p', 20 ),
			headings,
			links,
			buttons,
			forms: document.querySelectorAll( 'form' ).length,
			images,
			viewport: {
				width: window.innerWidth,
				height: window.innerHeight,
				documentWidth: document.documentElement.scrollWidth,
				documentHeight: document.documentElement.scrollHeight,
				hasHorizontalOverflow: document.documentElement.scrollWidth > window.innerWidth + 1,
			},
			potentialIssues: {
				missingImageAltCount: images.filter( ( image ) => ! image.alt ).length,
				brokenImageCount: images.filter( ( image ) => ! image.loaded ).length,
				emptySections,
				overflowingElements,
				hasH1: headings.some( ( heading ) => heading.level === 'h1' ),
				h1Count: headings.filter( ( heading ) => heading.level === 'h1' ).length,
			},
		};
	} );
}

async function inspectViewport(
	url: string,
	viewportName: ViewportName,
	includeScreenshot: boolean
) {
	const browser = await getSharedBrowser();
	const page = await browser.newPage( {
		ignoreHTTPSErrors: true,
		viewport: VIEWPORTS[ viewportName ],
	} );

	const consoleMessages: { type: string; text: string }[] = [];
	const pageErrors: string[] = [];
	const failedRequests: { url: string; errorText: string }[] = [];
	const badResponses: { url: string; status: number }[] = [];

	page.on( 'console', ( message ) => {
		if ( [ 'error', 'warning' ].includes( message.type() ) ) {
			consoleMessages.push( { type: message.type(), text: message.text().slice( 0, 500 ) } );
		}
	} );
	page.on( 'pageerror', ( error ) => pageErrors.push( error.message.slice( 0, 500 ) ) );
	page.on( 'requestfailed', ( request ) => {
		failedRequests.push( {
			url: request.url(),
			errorText: request.failure()?.errorText ?? 'unknown request failure',
		} );
	} );
	page.on( 'response', ( response ) => {
		if ( response.status() >= 400 ) {
			badResponses.push( { url: response.url(), status: response.status() } );
		}
	} );

	try {
		const response = await page.goto( url, { waitUntil: 'domcontentloaded', timeout: 30000 } );
		await page.waitForLoadState( 'networkidle', { timeout: 10000 } ).catch( () => undefined );
		await waitForImages( page, includeScreenshot );
		await page.addStyleTag( {
			content: `
				#wpadminbar { display: none !important; }
				html { margin-top: 0 !important; }
				::-webkit-scrollbar { display: none !important; }
				html, body { scrollbar-width: none !important; }
			`,
		} );

		const [ summary, ariaSnapshot ] = await Promise.all( [
			collectPageSummary( page ),
			collectAriaSnapshot( page ),
		] );
		const screenshot = includeScreenshot
			? ( await page.screenshot( { fullPage: true, type: 'png' } ) ).toString( 'base64' )
			: undefined;

		return {
			viewport: viewportName,
			url: page.url(),
			status: response?.status(),
			summary,
			ariaSnapshot,
			consoleMessages: consoleMessages.slice( 0, 30 ),
			pageErrors: pageErrors.slice( 0, 20 ),
			failedRequests: failedRequests.slice( 0, 20 ),
			badResponses: badResponses.slice( 0, 20 ),
			screenshot,
		};
	} finally {
		await page.close();
	}
}

export function registerInspectTools( server: McpServer ) {
	server.registerTool(
		'wpdev_site_inspect',
		{
			description:
				'Inspect a local WordPress site route with a real browser. Use this after creating or changing a site to verify structure, visible content, console errors, failed requests, responsive overflow, image issues, and optional screenshots. The tool starts the site if needed and only accepts site-relative routes.',
			inputSchema: {
				path: z.string().describe( SITE_PATH_DESCRIPTION ),
				route: z
					.string()
					.optional()
					.describe(
						'Site-relative route to inspect, for example "/", "/about/", or "/contact/".'
					),
				viewport: z
					.enum( [ 'desktop', 'mobile', 'both' ] )
					.optional()
					.describe( 'Viewport to inspect. Defaults to "desktop".' ),
				includeScreenshot: z
					.boolean()
					.optional()
					.describe(
						'Return PNG screenshot image content for each inspected viewport. Default: false.'
					),
			},
		},
		async ( { path, route, viewport, includeScreenshot } ) => {
			try {
				const normalizedRoute = normalizeRoute( route );
				const siteUrl = await getRunningSiteUrl( path );
				const pageUrl = buildPageUrl( siteUrl, normalizedRoute );
				const viewports =
					viewport === 'both'
						? ( [ 'desktop', 'mobile' ] as const )
						: ( [ viewport ?? 'desktop' ] as const );
				const inspections = await Promise.all(
					viewports.map( ( viewportName ) =>
						inspectViewport( pageUrl, viewportName, includeScreenshot ?? false )
					)
				);

				const structuredContent = {
					siteUrl,
					route: normalizedRoute,
					inspections: inspections.map( ( inspection ) => ( {
						...inspection,
						screenshot: inspection.screenshot ? '[returned as image content]' : undefined,
					} ) ),
				};

				return {
					content: [
						{
							type: 'text',
							text: JSON.stringify( structuredContent, null, 2 ),
						},
						...inspections
							.filter( ( inspection ) => inspection.screenshot )
							.map( ( inspection ) => ( {
								type: 'image' as const,
								data: inspection.screenshot as string,
								mimeType: 'image/png',
							} ) ),
					],
					structuredContent,
				};
			} catch ( error ) {
				return {
					content: [
						{
							type: 'text',
							text: `Site inspection failed: ${
								error instanceof Error ? error.message : String( error )
							}`,
						},
					],
					isError: true,
				};
			}
		}
	);
}
