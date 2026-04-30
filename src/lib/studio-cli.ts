import { spawn } from 'node:child_process';

const CLI_COMMAND = process.env.STUDIO_CLI_PATH || 'studio';

type CliResult = {
	stdout: string;
	stderr: string;
	exitCode: number;
};

function quoteCmdArg( value: string ) {
	return `"${ value.replace( /"/g, '""' ) }"`;
}

export function formatCliFailure( cmd: string, res: CliResult ) {
	return (
		`${ cmd } failed (exit ${ res.exitCode }).\n\n` +
		( res.stderr.trim() ? `stderr:\n${ res.stderr.trim() }\n\n` : '' ) +
		( res.stdout.trim() ? `stdout:\n${ res.stdout.trim() }` : '' )
	);
}

function resolveSpawnTarget( command: string, args: string[] ) {
	if ( process.platform === 'win32' ) {
		// Node 20.12+ blocks direct .cmd/.bat spawns (CVE-2024-27980).
		// Avoid shell:true because arguments with spaces (site names, paths)
		// then depend on Node/cmd.exe joining rules. Instead, call cmd.exe
		// explicitly and pass one fully quoted command line after /c.
		return {
			exe: 'cmd.exe',
			spawnArgs: [ '/d', '/s', '/c', [ command, ...args ].map( quoteCmdArg ).join( ' ' ) ],
		};
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
