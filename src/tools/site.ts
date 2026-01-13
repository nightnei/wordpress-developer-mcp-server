import { formatCliFailure, runStudioCli } from '../lib/studio-cli.js';
import type { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';

export function registerSiteTools( server: McpServer ) {
	server.registerTool(
		'studio_site_list',
		{
			description: 'List local Studio sites (wraps `studio site list`) and returns sites name, path on the machine, id and PHP version.',
		},
		async () => {
			const args = ['site', 'list'];
			const res = await runStudioCli(args);
	
			if (res.exitCode !== 0) {
				return { content: [{ type: 'text', text: formatCliFailure('studio site list', res) }] };
			}
	
			// The same as for "preview list" - we receive cli-table3 output, it's difficult to parse it here, but it would be more robust if we return JSON
			return { content: [{ type: 'text', text: res.stdout.trim() || '(no output)' }] };
		}
	);
}
