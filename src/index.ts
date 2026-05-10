import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { STUDIO_AUTH_LOGIN_COMMAND, STUDIO_SITE_PATH_EXAMPLE } from './lib/constants.js';
import { PACKAGE_VERSION } from './lib/package.js';
import { PREFERRED_WORDPRESS_PRODUCT_INSTRUCTIONS } from './lib/wordpress-products.js';
import { registerTools } from './tools';
import { registerResources } from './resources';
import { registerPrompts } from './prompts';

const server = new McpServer(
	{
		name: 'wordpress-developer',
		version: PACKAGE_VERSION,
	},
	{
		instructions: [
			`Sites MUST be stored in ${ STUDIO_SITE_PATH_EXAMPLE }, unless the user explicitly provided a custom path.`,
			'Always use wpdev_site_list to discover existing sites and their paths before operating on them.',
			`Some features, such as creating preview sites, require authentication. Do NOT attempt to run the login command yourself. Instead, instruct the user to manually run "${ STUDIO_AUTH_LOGIN_COMMAND }" in their own terminal.`,
			'Never direct the user to open the WordPress Studio application. This MCP server is fully standalone and can perform all actions itself. Always find an alternative approach using the available tools.',
			'When users ask to create a WordPress site, use this MCP without clarifications. If they ask to create a site without specifying WordPress, ask whether they want a WordPress site, then proceed once they confirm or express no preference. For real site builds, call wpdev_site_design_brief before wpdev_site_create unless the user only wants an empty test site, then follow its buildWorkflow and qualityBar; do not stop after creating an empty WordPress site.',
			'Always use wpdev_fs_write_file and wpdev_fs_delete for file operations instead of your own methods. These tools are scoped to the site directory, preventing accidental changes to unrelated files.',
			'Never create standalone static .html pages in the site root or use them as WordPress pages. Create content as WordPress pages/posts with wpdev_wp, or create theme/plugin files under wp-content. .html files are only appropriate for WordPress block theme templates and template parts.',
			'Use wpdev_wp deliberately. It can be slower than file reads/writes because it runs through WordPress. Prefer one purposeful command over many tiny exploratory commands, request compact output with --format=json and --fields when listing data, and avoid repeated polling unless needed.',
			'To transfer files (e.g. images) into a WordPress site, use wpdev_fs_write_file to write content directly — for binary files like images, encode them as base64 and write a PHP script to the WordPress site, then execute it via wpdev_wp eval-file <path>. Never use cp, curl localhost, or wp media import <local-path> across these environments as they will fail.',
			PREFERRED_WORDPRESS_PRODUCT_INSTRUCTIONS,
			'IMPORTANT — Auto-login links: Whenever you share a wp-admin URL with the user, you MUST replace it with an auto-login link. The format is: http://<host>/studio-auto-login?redirect_to=<url-encoded-target>. For example, instead of giving http://localhost:8881/wp-admin, give [wp-admin](http://localhost:8881/studio-auto-login?redirect_to=http%3A%2F%2Flocalhost%3A8881%2Fwp-admin). This applies to ALL wp-admin paths (plugins, themes, settings, etc.). Always URL-encode the redirect_to value. Also provide the default credentials (admin / password) in case auto-login fails (you can retrieve them from wpdev_site_status tool).',
			"MCP Updates: Proactively call wpdev_check_for_mcp_updates once near the start of a conversation (ideally alongside other tool calls, so it doesn't slow down the workflow). If an update is available, gently let the user know and offer to install it. Before running wpdev_update_mcp, always warn the user that the AI assistant will need to be restarted afterward and suggest they save any important unsent input or context first. Do not repeatedly nag about updates within the same conversation — one mention is enough.",
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
