import { registerPreviewTools } from './preview';
import { registerSiteTools } from './site';
import { registerAuthTools } from './auth';
import { registerFsTools } from './fs';
import { registerWpCliTools } from './wp-cli';
import { registerUpdateTools } from './update';
import { registerDesignTools } from './design';
import type { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';

export function registerTools( server: McpServer ) {
	registerPreviewTools( server );
	registerSiteTools( server );
	registerDesignTools( server );
	registerAuthTools( server );
	registerFsTools( server );
	registerWpCliTools( server );
	registerUpdateTools( server );
}
