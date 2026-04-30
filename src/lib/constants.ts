import { homedir, platform } from 'node:os';
import path from 'node:path';

export const STUDIO_SITES_DIR = path.join( homedir(), 'Studio' );
export const STUDIO_SITE_PATH_EXAMPLE = path.join( STUDIO_SITES_DIR, '<site-name>' );
export const STUDIO_AUTH_LOGIN_COMMAND =
	platform() === 'win32'
		? `~/.wordpress-developer-mcp/bin/studio-cli.cmd auth login`
		: `~/.wordpress-developer-mcp/bin/studio-cli auth login`;

export const SITE_PATH_DESCRIPTION =
	`Path to the root directory of a Studio site. Default location is ${ STUDIO_SITE_PATH_EXAMPLE }. Use wpdev_site_list to discover all sites and their paths.`;
