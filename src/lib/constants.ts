import { homedir } from 'node:os';

export const STUDIO_SITES_DIR = `${ homedir() }/Studio`;

export const SITE_PATH_DESCRIPTION =
	`Path to the root directory of a Studio site. Default location is ${ STUDIO_SITES_DIR }/<site-name>. Use wpdev_site_list to discover all sites and their paths.`;
