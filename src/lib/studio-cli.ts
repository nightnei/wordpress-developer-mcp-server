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
	if ( process.platform === 'win32' ) {
		// Direct .cmd spawning fails on current Node/Windows paths (EINVAL).
		// Invoke cmd.exe explicitly, but pass command/args as argv entries
		// instead of using shell:true or embedding extra quotes in the command.
		return { exe: 'cmd.exe', spawnArgs: [ '/d', '/s', '/c', command, ...args ] };
	}
	return { exe: command, spawnArgs: args };
}

export function runStudioCli( args: string[] ) {
	return new Promise< CliResult >( ( resolve ) => {
		const { exe, spawnArgs } = resolveSpawnTarget( CLI_COMMAND, args );

		const child = spawn( exe, spawnArgs, {
			/**
			 * 'ignore' for stdin: child can't ask interactive questions (safer, avoids hanging).
			 * 'pipe' for stdout: we want to capture normal output (e.g. `studio preview list` output).
			 * 'pipe' for stderr: we want to capture error output for debugging.
			 */
			stdio: [ 'ignore', 'pipe', 'pipe' ],
		} );

		let stdout = '';
		let stderr = '';
		let settled = false;

		child.stdout.on( 'data', ( d ) => ( stdout += d.toString( 'utf8' ) ) );
		child.stderr.on( 'data', ( d ) => ( stderr += d.toString( 'utf8' ) ) );

		child.on( 'error', ( error ) => {
			if ( settled ) return;
			settled = true;
			resolve( { stdout, stderr: stderr || error.message, exitCode: 1 } );
		} );

		child.on( 'close', ( code: number | null ) => {
			if ( settled ) return;
			settled = true;
			resolve( { stdout, stderr, exitCode: code ?? 0 } );
		} );
	} );
}

export function extractFirstWpBuildUrl( text: string ): string | undefined {
	const urlMatch = text.match( /https?:\/\/[^\s|]+\.wp\.build/ );
	return urlMatch?.[ 0 ];
}
