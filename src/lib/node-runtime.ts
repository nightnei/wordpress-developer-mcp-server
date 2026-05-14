import { existsSync } from 'node:fs';
import { dirname, join } from 'node:path';

function resolveRuntimeCommand( commandName: string ) {
	const commandFromCurrentNode = join( dirname( process.execPath ), commandName );

	if ( existsSync( commandFromCurrentNode ) ) {
		return commandFromCurrentNode;
	}

	return commandName;
}

export function resolveNpmCommand() {
	return resolveRuntimeCommand( process.platform === 'win32' ? 'npm.cmd' : 'npm' );
}
