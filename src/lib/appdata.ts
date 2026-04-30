import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';

const APPDATA_PATH = path.join( os.homedir(), '.studio', 'cli.json' );

function normalizeStudioPath( value: string ): string {
	const normalized = path.resolve( value );
	return process.platform === 'win32' ? normalized.toLowerCase() : normalized;
}

async function readAppData(): Promise< Record< string, any > > {
	try {
		const raw = await fs.readFile( APPDATA_PATH, { encoding: 'utf8' } );
		return JSON.parse( raw );
	} catch {
		return { sites: [] };
	}
}

export async function isStudioSitePath( sitePath: string ): Promise< boolean > {
	const normalizedSitePath = normalizeStudioPath( sitePath );

	const appdata = await readAppData();
	const sites: any[] = Array.isArray( appdata?.sites ) ? appdata.sites : [];
	const studioSitePaths = sites
		.filter( ( site ) => typeof site?.path === 'string' )
		.map( ( site ) => normalizeStudioPath( site.path ) );

	return studioSitePaths.includes( normalizedSitePath );
}
