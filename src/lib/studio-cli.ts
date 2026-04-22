import { spawn } from 'node:child_process';

const CLI_COMMAND = process.env.STUDIO_CLI_PATH || 'studio';

type CliResult = {
	stdout: string;
	stderr: string;
	exitCode: number;
};

export function formatCliFailure( cmd: string, res: CliResult ) {
	return (
		`${ cmd } failed (exit ${ res.exitCode }).\n\n` +
		( res.stderr.trim() ? `stderr:\n${ res.stderr.trim() }\n\n` : '' ) +
		( res.stdout.trim() ? `stdout:\n${ res.stdout.trim() }` : '' )
	);
}

function resolveSpawnTarget( command: string, args: string[] ) {
	if ( process.platform === 'win32' && /\.(cmd|bat)$/i.test( command ) ) {
		// Node 20.12+ blocks direct .cmd/.bat spawns (CVE-2024-27980), so use
		// shell:true (runs as `cmd.exe /d /s /c`). Node escapes args safely
		// post-CVE, but NOT the command itself, so we quote it here to survive
		// paths with spaces (e.g. `C:\Users\First Last\...`). The /s flag
		// preserves the command-line quoting verbatim.
		return { exe: `"${ command }"`, spawnArgs: args, useShell: true };
	}
	return { exe: command, spawnArgs: args, useShell: false };
}

export function runStudioCli( args: string[] ) {
	return new Promise< CliResult >( ( resolve ) => {
		const { exe, spawnArgs, useShell } = resolveSpawnTarget( CLI_COMMAND, args );

		const child = spawn( exe, spawnArgs, {
			shell: useShell,
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

export function extractFirstWpBuildUrl( text: string ): string | undefined {
	const urlMatch = text.match( /https?:\/\/[^\s|]+\.wp\.build/ );
	return urlMatch?.[ 0 ];
}
