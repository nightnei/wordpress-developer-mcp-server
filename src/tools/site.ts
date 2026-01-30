import { formatCliFailure, runStudioCli } from '../lib/studio-cli.js';
import type { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';

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
}
