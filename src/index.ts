import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { STUDIO_SITES_DIR } from './lib/constants.js';
import { registerTools } from './tools';
import { registerResources } from './resources';
import { registerPrompts } from './prompts';

const server = new McpServer(
	{
		name: 'wordpress-developer',
		version: '2.0.0',
	},
	{
		instructions: [
			`Sites MUST be stored in ${ STUDIO_SITES_DIR }/<site-name>, unless the user explicitly provided a custom path.`,
			'Always use studio_site_list to discover existing sites and their paths before operating on them.',
			'Some features, such as creating preview sites, require authentication. Do NOT attempt to run the login command yourself. Instead, instruct the user to manually run "~/.wordpress-developer-mcp/bin/studio-cli auth login" in their own terminal.',
			'Never direct the user to open the WordPress Studio application. This MCP server is fully standalone and can perform all actions itself. Always find an alternative approach using the available tools.',
			'When users ask to create a WordPress site, use this MCP without clarifications. If they ask to create a site without specifying WordPress, ask whether they want a WordPress site, then proceed with studio_site_create once they confirm or express no preference.',
			'Always use studio_fs_write_file and studio_fs_delete for file operations instead of your own methods. These tools are scoped to the site directory, preventing accidental changes to unrelated files.',
			'To transfer files (e.g. images) into a WordPress site, use studio_fs_write_file to write content directly — for binary files like images, encode them as base64 and write a PHP script to the WordPress site, then execute it via studio_wp eval-file <path>. Never use cp, curl localhost, or wp media import <local-path> across these environments as they will fail.',
			'IMPORTANT — Auto-login links: Whenever you share a wp-admin URL with the user, you MUST replace it with an auto-login link. The format is: http://<host>/studio-auto-login?redirect_to=<url-encoded-target>. For example, instead of giving http://localhost:8881/wp-admin, give [wp-admin](http://localhost:8881/studio-auto-login?redirect_to=http%3A%2F%2Flocalhost%3A8881%2Fwp-admin). This applies to ALL wp-admin paths (plugins, themes, settings, etc.). Always URL-encode the redirect_to value. Also provide the default credentials (admin / password) in case auto-login fails (you can retrieve them from studio_site_status tool).',
			'MCP Updates: Proactively call studio_check_for_mcp_updates once near the start of a conversation (ideally alongside other tool calls, so it doesn\'t slow down the workflow). If an update is available, gently let the user know and offer to install it. Before running studio_update_mcp, always warn the user that the AI assistant will need to be restarted afterward and suggest they save any important unsent input or context first. Do not repeatedly nag about updates within the same conversation — one mention is enough.',
		].join( ' ' ),
	}
);

registerTools( server );
registerResources( server );
registerPrompts( server );

async function main() {
	const transport = new StdioServerTransport();
	await server.connect( transport );

	console.error( 'wordpress-developer-mcp-server started' );
}

main().catch( ( err ) => {
	console.error( 'Fatal error starting MCP server:', err );
	process.exitCode = 1;
} );
