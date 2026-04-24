import { homedir } from 'node:os';
import { readFile } from 'node:fs/promises';
import { execSync } from 'node:child_process';
import type { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';

const INSTALL_DIR = `${ homedir() }/.wordpress-developer-mcp`;
const VERSION_FILE = `${ INSTALL_DIR }/mcp/.version`;
const MCP_REPO = 'nightnei/wordpress-developer-mcp-server';
const GITHUB_API_URL = `https://api.github.com/repos/${ MCP_REPO }/releases/latest`;
const INSTALL_SCRIPT_SH_URL = `https://raw.githubusercontent.com/${ MCP_REPO }/main/install.sh`;
const INSTALL_SCRIPT_PS1_URL = `https://raw.githubusercontent.com/${ MCP_REPO }/main/install.ps1`;

async function getCurrentVersion(): Promise< string | null > {
	try {
		const version = await readFile( VERSION_FILE, 'utf8' );
		return version.trim();
	} catch {
		return null;
	}
}

async function getLatestRelease(): Promise< { tagName: string; tarballUrl: string } | null > {
	try {
		const response = await fetch( GITHUB_API_URL, {
			headers: {
				Accept: 'application/vnd.github.v3+json',
				'User-Agent': 'wordpress-developer-mcp-server',
			},
		} );

		if ( ! response.ok ) {
			return null;
		}

		const data: any = await response.json();
		const tagName: string = data.tag_name;
		const asset = data.assets?.find( ( a: any ) => a.name.endsWith( '.tar.gz' ) );
		const tarballUrl =
			asset?.browser_download_url ||
			`https://github.com/${ MCP_REPO }/releases/download/${ tagName }/wordpress-developer-mcp-server-${ tagName }.tar.gz`;

		return { tagName, tarballUrl };
	} catch {
		return null;
	}
}

export function registerUpdateTools( server: McpServer ) {
	server.registerTool(
		'studio_check_for_mcp_updates',
		{
			description:
				'Check if a newer version of the WordPress Developer MCP Server is available. ' +
				'Proactively call this tool as soon as you use any other tool from this MCP server ' +
				'for the first time — include it in parallel in the same tool call batch, never ' +
				'on its own. For example: if the user asks to list sites, call studio_site_list ' +
				'and studio_check_for_mcp_updates together in the same batch. ' +
				'Do not call it more than once per day — if you already checked today, ' +
				'do not check again. If an update is available, briefly let the user know and ' +
				'offer to install it — do not interrupt their workflow.',
		},
		async () => {
			const currentVersion = await getCurrentVersion();

			if ( ! currentVersion ) {
				return {
					content: [
						{
							type: 'text' as const,
							text: 'Cannot determine current version.',
						},
					],
				};
			}

			const latest = await getLatestRelease();

			if ( ! latest ) {
				return {
					content: [
						{
							type: 'text' as const,
							text: 'Failed to check for updates. GitHub API may be unreachable.',
						},
					],
				};
			}

			if ( latest.tagName === currentVersion ) {
				return {
					content: [
						{
							type: 'text' as const,
							text: `MCP server is up to date (${ currentVersion }).`,
						},
					],
				};
			}

			return {
				content: [
					{
						type: 'text' as const,
						text:
							`Update available! Current: ${ currentVersion }, Latest: ${ latest.tagName }. ` +
							'Use studio_update_mcp to install the update. ' +
							'IMPORTANT: After updating, the AI assistant must be restarted for changes to take effect.',
					},
				],
			};
		}
	);

	server.registerTool(
		'studio_update_mcp',
		{
			description:
				'Update the WordPress Developer MCP Server to the latest version. ' +
				'IMPORTANT: Before running this tool, always warn the user that the AI assistant ' +
				'will need to be restarted afterward for changes to take effect, and suggest they ' +
				'save any unsent input or important context first. Only proceed after the user confirms.',
		},
		async () => {
			const previousVersion = await getCurrentVersion();
			let output = '';

			// TODO: once install.ps1 gains an `-Update` flag (parity with
			// install.sh --update), switch the Windows branch to
			// `& ([scriptblock]::Create((irm '<url>'))) -Update` so it skips
			// the interactive auth prompt and agent reconfiguration.
			const command =
				process.platform === 'win32'
					? `powershell -NoProfile -Command "irm '${ INSTALL_SCRIPT_PS1_URL }' | iex" 2>&1`
					: `curl -fsSL "${ INSTALL_SCRIPT_SH_URL }" | bash -s -- --update 2>&1`;

			try {
				output = execSync( command, { timeout: 300000, encoding: 'utf8' } );
			} catch ( error: any ) {
				const details = error.stdout?.toString?.() || error.message;
				return {
					content: [
						{
							type: 'text' as const,
							text: `Update failed:\n${ details }`,
						},
					],
				};
			}

			const newVersion = ( await getCurrentVersion() ) || 'unknown';
			const summary =
				previousVersion && previousVersion !== newVersion
					? `Updated MCP server from ${ previousVersion } to ${ newVersion }.`
					: `MCP server is at ${ newVersion }.`;

			return {
				content: [
					{
						type: 'text' as const,
						text:
							`${ summary }\n\n${ output }\n` +
							'Please restart the AI assistant now to apply the new version. ' +
							'The current session is still running the old version until restarted.',
					},
				],
			};
		}
	);
}
