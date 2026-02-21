import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { STUDIO_SITES_DIR } from './lib/constants.js';
import { registerTools } from './tools';
import { registerResources } from './resources';
import { registerPrompts } from './prompts';

const server = new McpServer(
	{
		name: 'studio',
		version: '0.1.0',
	},
	{
		instructions: [
			`Studio sites MUST be stored in ${ STUDIO_SITES_DIR }/<site-name>, unless the user explicitly provided a custom path.`,
			'Always use studio_site_list to discover existing sites and their paths before operating on them.',
			'Some features, such as creating preview sites, require authentication. Do NOT attempt to run the login command yourself. Instead, instruct the user to manually run "~/.studio-mcp/bin/studio-cli auth login" in their own terminal, as the flow opens a browser for interactive login.'
		].join( ' ' ),
	}
);

registerTools( server );
registerResources( server );
registerPrompts( server );

async function main() {
	const transport = new StdioServerTransport();
	await server.connect( transport );

	console.error( 'wordpress-studio-mcp-server started' );
}

main().catch( ( err ) => {
	console.error( 'Fatal error starting MCP server:', err );
	process.exitCode = 1;
} );
