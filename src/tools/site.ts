import { formatCliFailure, runStudioCli } from '../lib/studio-cli.js';
import { SITE_PATH_DESCRIPTION, STUDIO_SITES_DIR } from '../lib/constants.js';
import type { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { z } from 'zod';

export function registerSiteTools( server: McpServer ) {
	server.registerTool(
		'studio_site_list',
		{
			description: 'List all local WordPress Studio sites (wraps `studio site list`).',
		},
		async () => {
			const res = await runStudioCli( [ 'site', 'list', '--format=json' ] );

			if ( res.exitCode !== 0 ) {
				return {
					content: [
						{
							type: 'text',
							text: formatCliFailure( 'studio site list', res ),
						},
					],
				};
			}

			// TODO Studio CLI should return empty array if no sites are found
			let sites = [];
			try {
				sites = JSON.parse( res.stdout.trim() );
			} catch {
				// noop
			}
			const structuredContent = { sites };

			return {
				content: [
					{
						type: 'text',
						text: JSON.stringify( structuredContent, null, 2 ),
					},
				],
				structuredContent,
			};
		}
	);

	server.registerTool(
		'studio_site_status',
		{
			description:
				'Get detailed status of a Studio site including wp-admin username as adminUsername, wp-admin password as adminPassword, phpVersion, wpVersion, and Xdebug status (wraps `studio site status`).',
			inputSchema: {
				path: z.string().describe( SITE_PATH_DESCRIPTION ),
			},
		},
		async ( { path } ) => {
			const res = await runStudioCli( [ 'site', 'status', '--path', path, '--format=json' ] );

			if ( res.exitCode !== 0 ) {
				return {
					content: [
						{
							type: 'text',
							text: formatCliFailure( 'studio site status', res ),
						},
					],
				};
			}

			const status = JSON.parse( res.stdout.trim() );

			const structuredContent = { status };

			return {
				content: [
					{
						type: 'text',
						text: JSON.stringify( structuredContent, null, 2 ),
					},
				],
				structuredContent,
			};
		}
	);

	server.registerTool(
		'studio_site_start',
		{
			description:
				'Start a Studio site (wraps `studio site start`). Returns site URL and admin username.',
			inputSchema: {
				path: z.string().describe( SITE_PATH_DESCRIPTION ),
			},
		},
		async ( { path } ) => {
			const res = await runStudioCli( [
				'site',
				'start',
				'--path',
				path,
				'--skip-browser', // don't open browser (not useful for MCP)
			] );

			if ( res.exitCode !== 0 ) {
				return {
					content: [
						{
							type: 'text',
							text: formatCliFailure( 'studio site start', res ),
						},
					],
				};
			}

			return {
				content: [
					{
						type: 'text',
						text: res.stdout.trim(),
					},
				],
			};
		}
	);

	server.registerTool(
		'studio_site_stop',
		{
			description: 'Stop a Studio site or all sites (wraps `studio site stop`).',
			inputSchema: {
				path: z.string().optional().describe( SITE_PATH_DESCRIPTION ),
				all: z.boolean().optional().describe( 'Stop all sites (default: false).' ),
			},
		},
		async ( { path, all } ) => {
			if ( ! path && ! all ) {
				return {
					content: [
						{
							type: 'text',
							text: 'Must provide either path or all=true',
						},
					],
				};
			}

			const args = [ 'site', 'stop' ];
			if ( path ) args.push( '--path', path );
			if ( all ) args.push( '--all' );

			const res = await runStudioCli( args );

			if ( res.exitCode !== 0 ) {
				return {
					content: [
						{
							type: 'text',
							text: formatCliFailure( 'studio site stop', res ),
						},
					],
				};
			}

			return {
				content: [
					{
						type: 'text',
						text: res.stdout.trim() || ( all ? 'All sites stopped' : `Site at ${ path } stopped` ),
					},
				],
			};
		}
	);

	server.registerTool(
		'studio_site_delete',
		{
			description:
				'Delete a Studio site. Destructive: requires confirm=true. Optionally move site files to trash.',
			inputSchema: {
				path: z.string().describe( SITE_PATH_DESCRIPTION ),
				files: z
					.boolean()
					.optional()
					.describe(
						'Also move site files to trash (default: false). If false, only removes from Studio but folder remains.'
					),
				confirm: z.boolean().describe( 'Must be true to actually delete.' ),
			},
		},
		async ( { path, files, confirm } ) => {
			if ( ! confirm ) {
				return {
					content: [
						{
							type: 'text',
							text:
								`Refusing to delete site at "${ path }" because confirm=false.\n` +
								`Re-run with confirm=true if you're sure.`,
						},
					],
				};
			}

			const args = [ 'site', 'delete', '--path', path ];
			if ( files ) args.push( '--files' );

			const res = await runStudioCli( args );

			if ( res.exitCode !== 0 ) {
				return {
					content: [
						{
							type: 'text',
							text: formatCliFailure( 'studio site delete', res ),
						},
					],
				};
			}

			return {
				content: [
					{
						type: 'text',
						text: `Site deleted${ files ? ' (files moved to trash)' : '' }`,
					},
				],
			};
		}
	);

	server.registerTool(
		'studio_site_create',
		{
			description: `Create a new Studio site (wraps \`studio site create\`). If the user did not specify a custom path, you MUST use ${ STUDIO_SITES_DIR }/<site-name> as the default location. Use studio_site_list to discover all sites and their paths, to avoid using already existing paths.`,
			inputSchema: {
				path: z
					.string()
					.describe(
						`Path for the new site. MUST default to ${ STUDIO_SITES_DIR }/<site-name> unless the user explicitly provided a custom path.`
					),
				name: z.string().optional().describe( 'Site name.' ),
				wp: z
					.string()
					.optional()
					.describe( 'WordPress version (e.g., "latest", "6.4", "6.4.1"). Default: "latest".' ),
				php: z
					.enum( [ '8.4', '8.3', '8.2', '8.1', '8.0', '7.4', '7.3', '7.2' ] )
					.optional()
					.describe( 'PHP version. Default: "8.3".' ),
				blueprint: z.string().optional().describe( 'Path or URL to Blueprint JSON file.' ),
			},
		},
		async ( { path, name, wp, php, blueprint } ) => {
			const args = [ 'site', 'create', '--path', path, '--skip-browser' ];

			if ( name ) args.push( '--name', name );
			if ( wp ) args.push( '--wp', wp );
			if ( php ) args.push( '--php', php );
			if ( blueprint ) args.push( '--blueprint', blueprint );

			const res = await runStudioCli( args );

			if ( res.exitCode !== 0 ) {
				return {
					content: [
						{
							type: 'text',
							text: formatCliFailure( 'studio site create', res ),
						},
					],
				};
			}

			return {
				content: [
					{
						type: 'text',
						text: res.stdout.trim() || 'Site created',
					},
				],
			};
		}
	);

	server.registerTool(
		'studio_site_set',
		{
			description: 'Configure site settings (wraps `studio site set`).',
			inputSchema: {
				path: z.string().describe( SITE_PATH_DESCRIPTION ),
				name: z.string().optional().describe( 'Site name.' ),
				domain: z
					.string()
					.optional()
					.describe(
						'Custom domain (must end with .local). May require system password to modify /etc/hosts.'
					),
				https: z.boolean().optional().describe( 'Enable HTTPS (requires custom domain).' ),
				php: z
					.enum( [ '8.4', '8.3', '8.2', '8.1', '8.0', '7.4', '7.3', '7.2' ] )
					.optional()
					.describe( 'PHP version.' ),
				wp: z.string().optional().describe( 'WordPress version.' ),
				xdebug: z.boolean().optional().describe( 'Enable Xdebug (beta feature).' ),
			},
		},
		async ( { path, name, domain, https, php, wp, xdebug } ) => {
			const args = [ 'site', 'set', '--path', path ];

			if ( name ) args.push( '--name', name );
			if ( domain ) args.push( '--domain', domain );
			if ( https ) args.push( '--https' );
			if ( php ) args.push( '--php', php );
			if ( wp ) args.push( '--wp', wp );
			if ( xdebug !== undefined ) args.push( '--xdebug', String( xdebug ) );

			const res = await runStudioCli( args );

			if ( res.exitCode !== 0 ) {
				return {
					content: [
						{
							type: 'text',
							text: formatCliFailure( 'studio site set', res ),
						},
					],
				};
			}

			return {
				content: [
					{
						type: 'text',
						text: res.stdout.trim() || 'Site settings updated',
					},
				],
			};
		}
	);
}
