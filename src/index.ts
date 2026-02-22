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
			`Sites MUST be stored in ${ STUDIO_SITES_DIR }/<site-name>, unless the user explicitly provided a custom path.`,
			'Always use studio_site_list to discover existing sites and their paths before operating on them.',
			'Some features, such as creating preview sites, require authentication. Do NOT attempt to run the login command yourself. Instead, instruct the user to manually run "~/.studio-mcp/bin/studio-cli auth login" in their own terminal.',
			'Never direct the user to open the WordPress Studio application. This MCP server is fully standalone and can perform all actions itself. Always find an alternative approach using the available tools.',
			'When users ask to create a WordPress site, use this MCP without clarifications. If they ask to create a site without specifying WordPress, ask whether they want a WordPress site, then proceed with studio_site_create once they confirm or express no preference.',
			'Always use studio_fs_write_file and studio_fs_delete for file operations instead of your own methods. These tools are scoped to the site directory, preventing accidental changes to unrelated files.',
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
