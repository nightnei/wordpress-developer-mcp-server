import { formatCliFailure, runStudioCli } from '../lib/studio-cli.js';
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

			const structuredContent = {
				sites: JSON.parse( res.stdout.trim() ),
			};

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
				'Get detailed status of a Studio site including PHP version, WP version, and Xdebug status (wraps `studio site status`).',
			inputSchema: {
				path: z.string().describe( 'Path to the root directory of a Studio site.' ),
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

			delete status[ 'Admin password' ];

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
}
