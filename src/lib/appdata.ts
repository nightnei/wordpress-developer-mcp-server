import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';

const APPDATA_PATH = path.join(
	os.homedir(),
	'Library',
	'Application Support',
	'Studio',
	'appdata-v1.json'
);

export async function readAppData(): Promise< Record< string, any > > {
	const raw = await fs.readFile( APPDATA_PATH, { encoding: 'utf8' } );

	return JSON.parse( raw );
}

export async function isStudioSitePath(sitePath: string): Promise<boolean> {
	const normalizedSitePath = sitePath.endsWith(path.sep) ? sitePath : sitePath + path.sep;

	const appdata = await readAppData();
	const sites: any[] = Array.isArray(appdata?.sites) ? appdata.sites : [];
	const studioSitePaths = sites.map( ( site ) => {
		return site.path.endsWith(path.sep) ? site.path : site.path + path.sep;
	} );

	return studioSitePaths.includes(normalizedSitePath);
}
