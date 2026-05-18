import fs from 'node:fs/promises';
import os from 'node:os';
import nodePath from 'node:path';
import { formatAuthenticationRequired, formatCliFailure, runStudioCli } from '../lib/studio-cli.js';
import { SITE_PATH_DESCRIPTION } from '../lib/constants.js';
import type { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { z } from 'zod';

type WpcomSiteResponse = {
	ID: number;
	URL: string;
	name: string;
	is_deleted?: boolean;
	is_a8c?: boolean;
	is_wpcom_atomic?: boolean;
	jetpack?: boolean;
	hosting_provider_guess?: string;
	environment_type?: string | null;
	capabilities?: {
		manage_options?: boolean;
	};
	plan?: {
		product_name_short?: string;
		features?: {
			active?: string[];
		};
	};
	options?: {
		created_at?: string;
		wpcom_staging_blog_ids?: number[];
		software_version?: string;
	};
};

type WpcomSitesResponse = {
	sites?: WpcomSiteResponse[];
	total?: number;
};

async function getWpcomAccessToken() {
	const sharedConfigPath = nodePath.join( os.homedir(), '.studio', 'shared.json' );
	const raw = await fs.readFile( sharedConfigPath, 'utf8' ).catch( () => '' );
	if ( ! raw.trim() ) {
		return undefined;
	}

	const sharedConfig = JSON.parse( raw ) as {
		authToken?: { accessToken?: string; expirationTime?: number };
	};
	const token = sharedConfig.authToken;
	if ( ! token?.accessToken || ( token.expirationTime && Date.now() >= token.expirationTime ) ) {
		return undefined;
	}

	return token.accessToken;
}

function getSyncSupport( site: WpcomSiteResponse ) {
	if ( site.is_deleted ) return 'deleted';
	if ( ! site.capabilities?.manage_options ) return 'missing-permissions';
	if ( site.jetpack && ! site.is_wpcom_atomic && site.hosting_provider_guess !== 'pressable' ) {
		return 'unsupported';
	}
	if (
		! site.plan?.features?.active?.includes( 'studio-sync' ) &&
		site.hosting_provider_guess !== 'pressable'
	) {
		return 'needs-upgrade';
	}
	if ( ! site.jetpack && ! site.is_wpcom_atomic && site.hosting_provider_guess !== 'pressable' ) {
		return 'needs-transfer';
	}
	return 'syncable';
}

function toRemoteSiteSummary( site: WpcomSiteResponse ) {
	return {
		id: site.ID,
		name: site.name,
		url: site.URL,
		isStaging: site.environment_type === 'staging' || site.environment_type === 'development',
		isPressable: site.hosting_provider_guess === 'pressable',
		environmentType: site.environment_type,
		syncSupport: getSyncSupport( site ),
		wpVersion: site.options?.software_version,
		planName: site.plan?.product_name_short,
		createdAt: site.options?.created_at,
	};
}

async function fetchWpcomSites( search?: string ) {
	const token = await getWpcomAccessToken();
	if ( ! token ) {
		throw new Error( formatAuthenticationRequired( 'Fetching WordPress.com sites' ) );
	}

	const sites: WpcomSiteResponse[] = [];
	let page = 1;
	const perPage = 100;

	while ( true ) {
		const params = new URLSearchParams( {
			fields: [
				'name',
				'ID',
				'URL',
				'plan',
				'capabilities',
				'is_wpcom_atomic',
				'options',
				'jetpack',
				'is_deleted',
				'is_a8c',
				'hosting_provider_guess',
				'environment_type',
			].join( ',' ),
			filter: 'atomic,wpcom',
			options: 'created_at,wpcom_staging_blog_ids,software_version',
			site_activity: 'active',
			include_a8c_owned: 'false',
			page: String( page ),
			per_page: String( perPage ),
		} );
		if ( search ) {
			params.set( 'search', search );
		}

		const response = await fetch(
			`https://public-api.wordpress.com/rest/v1.3/me/sites?${ params.toString() }`,
			{ headers: { Authorization: `Bearer ${ token }` } }
		);
		if ( ! response.ok ) {
			throw new Error( `WordPress.com API request failed (${ response.status })` );
		}

		const data = ( await response.json() ) as WpcomSitesResponse;
		const pageSites = data.sites ?? [];
		sites.push( ...pageSites );

		const total = data.total ?? sites.length;
		if ( pageSites.length === 0 || sites.length >= total ) {
			break;
		}
		page++;
	}

	return sites.filter( ( site ) => ! site.is_a8c ).map( ( site ) => toRemoteSiteSummary( site ) );
}

export function registerSyncTools( server: McpServer ) {
	server.registerTool(
		'wpdev_wpcom_site_list',
		{
			description:
				"Fetch the authenticated user's WordPress.com sites live from WordPress.com. Use this before wpdev_site_push or wpdev_site_pull to choose a remote site URL or ID. A prior local-to-remote connection is not required; push and pull connect during the operation.",
			inputSchema: {
				search: z
					.string()
					.optional()
					.describe( 'Optional search term to filter WordPress.com sites.' ),
			},
		},
		async ( { search } ) => {
			try {
				const sites = await fetchWpcomSites( search );
				const structuredContent = { sites };

				return {
					content: [ { type: 'text', text: JSON.stringify( structuredContent, null, 2 ) } ],
					structuredContent,
				};
			} catch ( error ) {
				const message = error instanceof Error ? error.message : String( error );
				return {
					content: [
						{
							type: 'text',
							text: message.includes( 'requires WordPress.com authentication' )
								? message
								: `Failed to fetch WordPress.com sites: ${ message }`,
						},
					],
					isError: true,
				};
			}
		}
	);

	server.registerTool(
		'wpdev_site_push',
		{
			description:
				'Push a local WordPress site to a WordPress.com site. Requires WordPress.com authentication. Use wpdev_wpcom_site_list first to choose the remote site. A prior connection is not required; the CLI connects during push. Always syncs all parts of the site. This modifies the remote site, so only call after the user confirms the target remote site.',
			inputSchema: {
				path: z.string().describe( SITE_PATH_DESCRIPTION ),
				remoteSite: z
					.string()
					.describe( 'Remote WordPress.com site URL or numeric site ID to push to.' ),
				confirm: z.boolean().describe( 'Must be true to push changes to the remote site.' ),
			},
		},
		async ( { path, remoteSite, confirm } ) => {
			if ( ! confirm ) {
				return {
					content: [
						{
							type: 'text',
							text:
								`Refusing to push "${ path }" to "${ remoteSite }" because confirm=false.\n` +
								'Re-run with confirm=true after the user confirms the remote target.',
						},
					],
				};
			}

			const res = await runStudioCli( [
				'push',
				'--path',
				path,
				'--remote-site',
				remoteSite,
				'--options',
				'all',
			] );

			if ( res.exitCode !== 0 ) {
				return {
					content: [ { type: 'text', text: formatCliFailure( 'studio push', res ) } ],
					isError: true,
				};
			}

			return {
				content: [
					{ type: 'text', text: res.stdout.trim() || res.stderr.trim() || 'Push completed.' },
				],
			};
		}
	);

	server.registerTool(
		'wpdev_site_pull',
		{
			description:
				'Pull a WordPress.com site into a local WordPress site. Requires WordPress.com authentication. Use wpdev_wpcom_site_list first to choose the remote source. A prior connection is not required; the CLI connects during pull. Always syncs all parts of the site. This modifies the local site, so only call after the user confirms the local site and remote source.',
			inputSchema: {
				path: z.string().describe( SITE_PATH_DESCRIPTION ),
				remoteSite: z
					.string()
					.describe( 'Remote WordPress.com site URL or numeric site ID to pull from.' ),
				confirm: z.boolean().describe( 'Must be true to pull changes into the local site.' ),
			},
		},
		async ( { path, remoteSite, confirm } ) => {
			if ( ! confirm ) {
				return {
					content: [
						{
							type: 'text',
							text:
								`Refusing to pull "${ remoteSite }" into "${ path }" because confirm=false.\n` +
								'Re-run with confirm=true after the user confirms the local site and remote source.',
						},
					],
				};
			}

			const res = await runStudioCli( [
				'pull',
				'--path',
				path,
				'--remote-site',
				remoteSite,
				'--options',
				'all',
			] );

			if ( res.exitCode !== 0 ) {
				return {
					content: [ { type: 'text', text: formatCliFailure( 'studio pull', res ) } ],
					isError: true,
				};
			}

			return {
				content: [
					{ type: 'text', text: res.stdout.trim() || res.stderr.trim() || 'Pull completed.' },
				],
			};
		}
	);
}
