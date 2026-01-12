import { spawn } from 'node:child_process';
import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { z } from 'zod';

function formatCliFailure(cmd: string, res: { stdout: string; stderr: string; exitCode: number }) {
	return (
		`${ cmd } failed (exit ${ res.exitCode }).\n\n` +
		( res.stderr.trim() ? `stderr:\n${ res.stderr.trim() }\n\n` : '' ) +
		( res.stdout.trim() ? `stdout:\n${ res.stdout.trim() }` : '' )
	);
}

function runStudioCli( args: string[] ) {
	return new Promise< { stdout: string; stderr: string; exitCode: number } >( ( resolve ) => {
		const child = spawn( 'studio', args, {
			/**
			 * 'ignore' for stdin: child can't ask interactive questions (safer, avoids hanging).
			 * 'pipe' for stdout: we want to capture normal output (e.g. `studio preview list` output).
			 * 'pipe' for stderr: we want to capture error output for debugging.
			 */
			stdio: [ 'ignore', 'pipe', 'pipe' ],
		} );

		let stdout = '';
		let stderr = '';

		child.stdout.on( 'data', ( d ) => ( stdout += d.toString( 'utf8' ) ) );
		child.stderr.on( 'data', ( d ) => ( stderr += d.toString( 'utf8' ) ) );

		child.on( 'close', ( code: number | null ) => {
			resolve( { stdout, stderr, exitCode: code ?? 0 } );
		} );
	} );
}

const server = new McpServer( {
	name: 'studio',
	version: '0.1.0',
} );

server.registerTool(
	'studio_preview_list',
	{
		description: 'List Studio preview sites for a given path of the original Studio site.',
		inputSchema: {
			path: z.string().describe( 'Path to the root directory of a Studio site.' ),
		},
	},
	async ( { path } ) => {
		const args = [ 'preview', 'list' ];
		args.push( '--path', path );

		const res = await runStudioCli( args );

		if ( res.exitCode !== 0 ) {
			return {
				content: [
					{
						type: 'text',
						text: formatCliFailure('studio preview list', res),
					},
				],
			};
		}

		// 1. We receive cli-table3 output, it's difficult to parse it and it would be not robust solution.
		// As option, we could add flag to the original command to receive json output instead of table.
		// it seems we can distinguish it with process.stdout.isTTY
		// 2. If there are no previews - CLI prints "No preview sites found" to "stderr". Would be cool to print to stdout for consistency.
		return {
			content: [ { type: 'text', text: res.stdout.trim() || 'No preview sites found' } ],
		};
	}
);

server.registerTool(
	'studio_preview_create',
	{
		description: 'Create a Studio preview site for a given path of the original Studio site.',
		inputSchema: {
			path: z.string().describe( 'Path to the root directory of a Studio site.' ),
		},
	},
	async ( { path } ) => {
		const args = [ 'preview', 'create' ];
		args.push( '--path', path );

		const res = await runStudioCli( args );

		if ( res.exitCode !== 0 ) {
			return {
				content: [
					{
						type: 'text',
						text: formatCliFailure('studio preview create', res),
					},
				],
			};
		}

		// Studio CLI prints the URL to the preview site in the stderr output.
		// I think we can keep it there, but additionally print to stdout, with extra information as site name, etc.
		const urlMatch = res.stderr.match( /https?:\/\/[^\s|]+\.wp\.build/ );
		const url = urlMatch?.[ 0 ];

		return {
			content: [
				{
					type: 'text',
					text: url ? `Created preview: ${ url }` : res.stdout.trim() || '(no output)',
				},
			],
		};
	}
);

server.registerTool(
	'studio_preview_update',
	{
		description: 'Update a Studio preview site for a given original site path (wraps `studio preview update <host>`).',
		inputSchema: {
			host: z.string().min(1).describe('Hostname of the preview site to update (the <host> argument).'),
			path: z.string().describe('Path to the root directory of a Studio site.'),
			overwrite: z
				.boolean()
				.optional()
				.describe('Allow updating a preview site from a different folder (maps to --overwrite). Note, the preview site will be deleted for the old site path and created for the new one, but es expected - the host will be preserved.'),
		},
	},
	async ({ host, path, overwrite }) => {
		const args = ['preview', 'update', host, '--path', path];
		if (overwrite) args.push('--overwrite');

		const res = await runStudioCli(args);

		if (res.exitCode !== 0) {
			return {
				content: [
					{
						type: 'text',
						text: formatCliFailure('studio preview update', res)
					},
				],
			};
		}

		return {
			// stdout doesn't have any information, and it's better to print teh host directly, instead of printing the whole stderr output
			content: [{ type: 'text', text: `Updated preview: ${ host }` || '(no output)' }],
		};
	}
);

server.registerTool(
	'studio_preview_delete',
	{
		description:
			'Delete a Studio preview site by its hostname (e.g. "my-preview-site.wp.build"). Destructive: requires confirm=true.',
		inputSchema: {
			host: z
				.string()
				.min( 1 )
				.describe( 'Preview host to delete (e.g. "my-preview-site.wp.build").' ),
			confirm: z.boolean().describe( 'Must be true to actually delete.' ),
		},
	},
	async ( { host, confirm } ) => {
		if ( ! confirm ) {
			return {
				content: [
					{
						type: 'text',
						text:
							`Refusing to delete preview site "${ host }" because confirm=false.\n` +
							`Re-run with confirm=true if you're sure.`,
					},
				],
			};
		}

		const args = [ 'preview', 'delete', host ];

		const res = await runStudioCli( args );

		if ( res.exitCode !== 0 ) {
			return {
				content: [
					{
						type: 'text',
						text: formatCliFailure('studio preview delete', res),
					},
				],
			};
		}

		return {
			content: [ { type: 'text', text: `Deleted ${ host } successfully` } ],
		};
	}
);

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

async function main() {
	const transport = new StdioServerTransport();
	await server.connect( transport );

	console.error( 'wordpress-studio-mcp-server started' );
}

main().catch( ( err ) => {
	console.error( 'Fatal error starting MCP server:', err );
	process.exitCode = 1;
} );
