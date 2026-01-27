import fs from 'node:fs/promises';
import path from 'node:path';
import { z } from 'zod';
import type { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { isStudioSitePath } from '../lib/appdata';

const MAX_READ_BYTES = 200 * 1024;

function resolveInsideRoot( root: string, rel: string ) {
	const rootReal = path.resolve( root );
	const target = path.resolve( rootReal, rel );

	// Ensure target is inside root
	const rootRealWithTrailingSlash = rootReal.endsWith( path.sep ) ? rootReal : rootReal + path.sep;
	if ( target !== rootReal && ! target.startsWith( rootRealWithTrailingSlash ) ) {
		throw new Error(
			`Path escapes site root. root="${ rootReal }", requested="${ rel }", resolved="${ target }"`
		);
	}

	return target;
}

async function isDirectory( p: string ) {
	try {
		const st = await fs.stat( p );
		return st.isDirectory();
	} catch {
		return false;
	}
}

export function registerFsTools( server: McpServer ) {
	server.registerTool(
		'studio_fs_list_dir',
		{
			description:
				'List files/folders inside a Studio site directory. Safe: only allows paths within the given sitePath.',
			inputSchema: {
				sitePath: z.string().describe( 'Absolute path to the Studio site root folder.' ),
				relPath: z
					.string()
					.optional()
					.describe( 'Relative path within the site folder (default: ".").' ),
				includeHidden: z.boolean().optional().describe( 'Include dotfiles (default: false).' ),
			},
		},
		async ( { sitePath, relPath, includeHidden } ) => {
			const rel = relPath ?? '.';

			if ( ! ( await isDirectory( sitePath ) ) ) {
				return {
					content: [
						{ type: 'text', text: `sitePath is not a directory or does not exist: ${ sitePath }` },
					],
				};
			}

			if ( ! ( await isStudioSitePath( sitePath ) ) ) {
				return {
					content: [
						{
							type: 'text',
							text: `sitePath is not a known Studio site: ${ sitePath }. Tip: open Studio and ensure the site exists there.`,
						},
					],
				};
			}

			let target: string;
			try {
				target = resolveInsideRoot( sitePath, rel );
			} catch ( e: any ) {
				return { content: [ { type: 'text', text: e?.message || 'Unknown error' } ] };
			}

			const entries = await fs.readdir( target, { withFileTypes: true } );

			const filtered = entries
				.filter( ( entry ) => ( includeHidden ? true : ! entry.name.startsWith( '.' ) ) )
				.map( ( entry ) => ( {
					name: entry.name,
					type: entry.isDirectory()
						? 'dir'
						: entry.isFile()
						? 'file'
						: entry.isSymbolicLink()
						? 'symlink'
						: 'other',
				} ) )
				.sort( ( a, b ) => a.name.localeCompare( b.name ) );

			const structuredContent = {
				sitePath,
				relPath: rel,
				entries: filtered,
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
		'studio_fs_read_file',
		{
			description:
				'Read a text file inside a Studio site directory. Safe: only allows files within the given sitePath. Has a size limit.',
			inputSchema: {
				sitePath: z.string().describe( 'Absolute path to the Studio site root folder.' ),
				relPath: z.string().describe( 'Relative path to a file within the site folder.' ),
				maxBytes: z
					.number()
					.int()
					.positive()
					.optional()
					.describe( `Max bytes to read (default: ${ MAX_READ_BYTES }).` ),
			},
		},
		async ( { sitePath, relPath, maxBytes } ) => {
			const limit = maxBytes ?? MAX_READ_BYTES;

			if ( ! ( await isDirectory( sitePath ) ) ) {
				return {
					content: [
						{ type: 'text', text: `sitePath is not a directory or does not exist: ${ sitePath }` },
					],
				};
			}

			if ( ! ( await isStudioSitePath( sitePath ) ) ) {
				return {
					content: [
						{
							type: 'text',
							text: `sitePath is not a known Studio site: ${ sitePath }. Tip: open Studio and ensure the site exists there.`,
						},
					],
				};
			}

			let target: string;
			try {
				target = resolveInsideRoot( sitePath, relPath );
			} catch ( e: any ) {
				return { content: [ { type: 'text', text: e?.message || 'Unknown error' } ] };
			}

			const st = await fs.stat( target );
			if ( ! st.isFile() ) {
				return { content: [ { type: 'text', text: `Not a file: ${ relPath }` } ] };
			}

			if ( st.size > limit ) {
				return {
					content: [
						{
							type: 'text',
							text:
								`File is too large (${ st.size } bytes). Limit is ${ limit } bytes.\n` +
								`Tip: increase maxBytes or read a smaller file.`,
						},
					],
				};
			}

			const text = await fs.readFile( target, { encoding: 'utf8' } );

			return {
				content: [ { type: 'text', text } ],
				structuredContent: {
					sitePath,
					relPath,
					bytes: st.size,
				},
			};
		}
	);

	server.registerTool(
		'studio_fs_write_file',
		{
			description:
				'Write content to a file inside a Studio site directory. Safe: only allows paths within the given sitePath.',
			inputSchema: {
				sitePath: z.string().describe( 'Absolute path to the Studio site root folder.' ),
				relPath: z.string().describe( 'Relative path to the file within the site folder.' ),
				content: z.string().describe( 'Content to write.' ),
				createDirs: z
					.boolean()
					.optional()
					.describe( 'Create parent directories if they do not exist (default: false).' ),
			},
		},
		async ( { sitePath, relPath, content, createDirs } ) => {
			if ( ! ( await isDirectory( sitePath ) ) ) {
				return {
					content: [
						{ type: 'text', text: `sitePath is not a directory or does not exist: ${ sitePath }` },
					],
				};
			}

			if ( ! ( await isStudioSitePath( sitePath ) ) ) {
				return {
					content: [
						{
							type: 'text',
							text: `sitePath is not a known Studio site: ${ sitePath }. Tip: open Studio and ensure the site exists there.`,
						},
					],
				};
			}

			let target: string;
			try {
				target = resolveInsideRoot( sitePath, relPath );
			} catch ( e: any ) {
				return { content: [ { type: 'text', text: e?.message || 'Unknown error' } ] };
			}

			// Optionally create parent directories
			if ( createDirs ) {
				const dir = path.dirname( target );
				await fs.mkdir( dir, { recursive: true } );
			}

			await fs.writeFile( target, content, { encoding: 'utf8' } );

			const st = await fs.stat( target );

			return {
				content: [
					{
						type: 'text',
						text: `Successfully wrote ${ st.size } bytes to ${ relPath }`,
					},
				],
				structuredContent: {
					sitePath,
					relPath,
					bytes: st.size,
				},
			};
		}
	);

	server.registerTool(
		'studio_fs_delete_file',
		{
			description:
				'Delete a file inside a Studio site directory. Safe: only allows paths within the given sitePath. Cannot delete directories.',
			inputSchema: {
				sitePath: z.string().describe( 'Absolute path to the Studio site root folder.' ),
				relPath: z.string().describe( 'Relative path to the file within the site folder.' ),
			},
		},
		async ( { sitePath, relPath } ) => {
			if ( ! ( await isDirectory( sitePath ) ) ) {
				return {
					content: [
						{ type: 'text', text: `sitePath is not a directory or does not exist: ${ sitePath }` },
					],
				};
			}

			if ( ! ( await isStudioSitePath( sitePath ) ) ) {
				return {
					content: [
						{
							type: 'text',
							text: `sitePath is not a known Studio site: ${ sitePath }. Tip: open Studio and ensure the site exists there.`,
						},
					],
				};
			}

			let target: string;
			try {
				target = resolveInsideRoot( sitePath, relPath );
			} catch ( e: any ) {
				return { content: [ { type: 'text', text: e?.message || 'Unknown error' } ] };
			}

			let st;
			try {
				st = await fs.stat( target );
			} catch {
				return {
					content: [ { type: 'text', text: `File does not exist: ${ relPath }` } ],
				};
			}

			// Only allow deleting files, not directories
			if ( ! st.isFile() ) {
				return {
					content: [
						{
							type: 'text',
							text: `Cannot delete: ${ relPath } is not a file. Only files can be deleted.`,
						},
					],
				};
			}

			await fs.unlink( target );

			return {
				content: [
					{
						type: 'text',
						text: `Successfully deleted ${ relPath }`,
					},
				],
				structuredContent: {
					sitePath,
					relPath,
					deleted: true,
				},
			};
		}
	);
}
