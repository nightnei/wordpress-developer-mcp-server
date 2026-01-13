import { registerPreviewTools } from './preview';
import { registerSiteTools } from './site';
import { registerAuthTools } from './auth';
import type { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';

export function registerTools( server: McpServer ) {
	registerPreviewTools( server );
	registerSiteTools( server );
	registerAuthTools( server );
}
