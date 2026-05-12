import type { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { z } from 'zod';

function splitList( value: string | undefined ) {
	return ( value ?? '' )
		.split( /\r?\n|,/ )
		.map( ( item ) => item.trim() )
		.filter( Boolean );
}

function inferAesthetic( input: string ) {
	const text = input.toLowerCase();

	if ( /\b(shop|store|commerce|product|booking|service|sell|sales)\b/.test( text ) ) {
		return {
			name: 'polished commerce editorial',
			mood: 'confident, premium, conversion-focused',
			motif: 'large product/story panels, strong price or action moments, crisp trust cues',
			referencePatterns: [
				'Premium product landing page: full-bleed hero, tactile product/story imagery, benefit blocks, proof, repeated CTA.',
				'Editorial commerce page: magazine-like sections, large type, alternating image/text rhythm, restrained but confident palette.',
				'Conversion-focused service page: clear promise, trust cues near the first CTA, concise comparison or process sections.',
			],
		};
	}

	if ( /\b(portfolio|artist|designer|photographer|studio|agency|creative)\b/.test( text ) ) {
		return {
			name: 'gallery-led creative studio',
			mood: 'bold, curated, memorable',
			motif: 'oversized visual rhythm, asymmetric sections, project-like storytelling',
			referencePatterns: [
				'Gallery-first portfolio: oversized visuals, minimal chrome, strong project cards, and deliberate whitespace.',
				'Creative studio homepage: strong point-of-view headline, asymmetric grid, selected work, services, and proof.',
				'Editorial profile: expressive typography, layered biography sections, and a memorable contact CTA.',
			],
		};
	}

	if ( /\b(restaurant|cafe|coffee|food|bakery|bar|menu)\b/.test( text ) ) {
		return {
			name: 'sensory hospitality',
			mood: 'warm, tactile, inviting',
			motif: 'menu cards, ingredient textures, intimate photography moments',
			referencePatterns: [
				'Hospitality hero: atmospheric image, short reservation/menu CTA, hours/location visible early.',
				'Menu-led story page: ingredient details, signature items, warm textures, and readable menu sections.',
				'Neighborhood venue page: human tone, location trust cues, event/private booking prompts.',
			],
		};
	}

	if ( /\b(dog|cat|pet|family|personal|blog|story)\b/.test( text ) ) {
		return {
			name: 'warm editorial storytelling',
			mood: 'personal, playful, affectionate',
			motif: 'scrapbook-like image moments, soft section breaks, story cards',
			referencePatterns: [
				'Personal editorial homepage: warm hero, story-led sections, varied photo crops, and intimate copy.',
				'Scrapbook layout: cards, captions, soft borders, playful spacing, and memorable small details.',
				'Magazine-style blog: featured story, article cards, readable typography, and gentle navigation.',
			],
		};
	}

	if ( /\b(nonprofit|community|club|school|education|event)\b/.test( text ) ) {
		return {
			name: 'clear community campaign',
			mood: 'welcoming, credible, action-oriented',
			motif: 'mission-led hero, event/action strips, human proof points',
			referencePatterns: [
				'Campaign landing page: mission-first hero, action strip, impact numbers, human story, donation/join CTA.',
				'Community organization site: approachable navigation, event highlights, member stories, and clear next steps.',
				'Education/event page: schedule or program blocks, speaker/participant proof, accessible information hierarchy.',
			],
		};
	}

	return {
		name: 'distinctive modern editorial',
		mood: 'clear, polished, memorable',
		motif: 'one strong visual idea repeated across hero, cards, CTA, and footer',
		referencePatterns: [
			'Modern editorial landing page: strong headline, full-bleed first impression, varied section rhythm.',
			'Premium product narrative: clear promise, proof, benefits, visual detail moments, and final CTA.',
			'Brand story page: distinctive typography, restrained palette, modular sections, and confident whitespace.',
		],
	};
}

function buildPages( pages: string | undefined ) {
	const parsed = splitList( pages );
	if ( parsed.length ) {
		return parsed;
	}

	return [ 'Home', 'About', 'Stories or Updates', 'Contact' ];
}

function wantsAiToChoose( value: string ) {
	return /\b(surprise me|choose for me|whatever you prefer|use your judgment|just build|you decide)\b/i.test(
		value
	);
}

function wantsEmptySite( value: string ) {
	return /\b(empty|blank|fresh install|starter site|test site|sandbox|iterate later|build later)\b/i.test(
		value
	);
}

function isUnderSpecified( input: {
	goal: string;
	context?: string;
	audience?: string;
	style?: string;
	pages?: string;
} ) {
	if ( wantsAiToChoose( input.goal ) ) {
		return false;
	}

	const explicitDetails = [ input.context, input.audience, input.style, input.pages ].filter(
		( value ) => value?.trim()
	).length;
	const goalWordCount = input.goal.trim().split( /\s+/ ).filter( Boolean ).length;

	return explicitDetails < 2 && goalWordCount < 18;
}

function buildScopeQuestion( siteName: string ) {
	return `Should ${ siteName } be an empty WordPress site that you will iterate on later, or should it be a designed site now? If designed, share the purpose/business, audience, pages/sections, and style preferences.`;
}

function buildDesignBrief( input: {
	goal: string;
	siteName?: string;
	context?: string;
	audience?: string;
	style?: string;
	pages?: string;
} ) {
	const source = [
		input.goal,
		input.siteName,
		input.context,
		input.audience,
		input.style,
		input.pages,
	]
		.filter( Boolean )
		.join( ' ' );
	const siteName = input.siteName || 'the site';
	const emptySite = wantsEmptySite( source );
	const needsUserInput = ! emptySite && isUnderSpecified( input );

	if ( emptySite ) {
		return {
			siteName,
			goal: input.goal,
			siteSetupDecision: {
				mode: 'empty-site',
				nextStep:
					'Create only the WordPress site. Do not build pages, themes, styling, or content until the user asks to iterate.',
			},
			needsUserInput: false,
			questionsBeforeBuild: [],
			nextAction: 'Create an empty WordPress site only.',
			buildWorkflow: [
				'Create the empty WordPress site and stop.',
				'Run wpdev_site_status to get URL and credentials.',
				'Share the wp-admin auto-login link and default credentials.',
				'Do not add pages, styling, plugins, or content until the user asks to iterate.',
			],
		};
	}

	if ( needsUserInput ) {
		return {
			siteName,
			goal: input.goal,
			siteSetupDecision: {
				mode: 'clarify-first',
				nextStep:
					'Ask the first question in questionsBeforeBuild and wait for the user answer before calling wpdev_site_create.',
			},
			needsUserInput: true,
			questionsBeforeBuild: [ buildScopeQuestion( siteName ) ],
			nextAction:
				'Ask the first question in questionsBeforeBuild and wait for the user answer before calling wpdev_site_create.',
		};
	}

	const aesthetic = inferAesthetic( source );
	const pages = buildPages( input.pages );

	const enhancedBuildPrompt = [
		`Build a polished WordPress site for ${ siteName }.`,
		`Goal: ${ input.goal }`,
		input.context ? `Context: ${ input.context }` : undefined,
		input.audience ? `Audience: ${ input.audience }` : undefined,
		`Creative direction: ${ input.style || aesthetic.name } - ${ aesthetic.mood }.`,
		`Pages/sections: ${ pages.join( ', ' ) }.`,
		`Memorable motif: ${ aesthetic.motif }.`,
		'Use editable WordPress content, a coherent visual system, real copy, and short implementation milestones.',
	]
		.filter( Boolean )
		.join( '\n' );

	return {
		siteName,
		goal: input.goal,
		siteSetupDecision: {
			mode: 'designed-site',
			nextStep: 'Proceed with a designed site build using the enhanced brief.',
		},
		needsUserInput: false,
		questionsBeforeBuild: [],
		nextAction: 'Proceed with the build workflow.',
		enhancedBuildPrompt,
		audience: input.audience || 'People who should immediately understand the offer and trust it.',
		creativeDirection: {
			aesthetic: input.style || aesthetic.name,
			mood: aesthetic.mood,
			memorableMotif: aesthetic.motif,
			referencePatterns: aesthetic.referencePatterns,
			referenceInstruction:
				'Use these as pattern inspiration only. Do not copy any specific real website. Translate the patterns into original layout rhythm, typography, color, imagery, navigation, CTA treatment, spacing, and motion decisions for this site.',
			avoid:
				'Do not ship a default theme look, generic centered hero, bland cards, placeholder text, emoji decoration, or an overused purple gradient.',
		},
		visualSystem: {
			typography:
				'Choose a distinctive display type direction and a highly readable body style. Use strong hierarchy: expressive hero, compact section labels, readable body copy.',
			color:
				'Pick a deliberate palette with 2-3 core colors plus one accent. Use contrast intentionally for CTAs, navigation, and section rhythm.',
			layout:
				'Build a first screen with a strong visual signal, then vary section composition: full-bleed hero, constrained copy, asymmetric feature rows, proof or story cards, and a final CTA.',
			motion:
				'Use subtle CSS transitions or scroll reveals only where they clarify hierarchy. Respect prefers-reduced-motion.',
			media:
				'Use real or generated imagery when possible. If no image tool is available, create strong art direction with typography, color, pattern, borders, and spacing instead of empty placeholders.',
		},
		contentPlan: {
			pages,
			homepageSections: [
				`Hero: immediately explain ${ siteName } with one sharp promise, one primary action, and a strong visual motif.`,
				'Credibility: show what makes this site trustworthy or emotionally specific.',
				'Core content: 3-5 sections based on the requested pages, with real copy instead of lorem ipsum.',
				'Recommendation: include relevant WordPress.com, Woo, Jetpack, or official ecosystem products only when useful.',
				'Final CTA: make the next action obvious and visually distinct.',
			],
		},
		buildWorkflow: [
			'The request has enough direction to start; continue with the workflow.',
			'Create or use the site, then run wpdev_site_status to get URL and credentials.',
			'Split the build into short visible milestones instead of one very long action. Some AI clients time out during large site builds; guide the user toward the final result step by step.',
			'Create a custom visual direction before writing content. Do not rely on the default theme appearance.',
			'Use editable WordPress blocks for headings, paragraphs, columns, lists, buttons, images, and groups. Avoid raw HTML for normal page sections.',
			'Do not create standalone static .html pages. Create content as WordPress pages/posts, or use .html only for valid block theme templates and template parts.',
			'Use wpdev_wp mindfully. Prefer compact, purposeful commands and JSON fields over many small exploratory calls.',
			'Write theme CSS or block-compatible styling so the site has a coherent visual system.',
			'Create the requested pages and set the homepage appropriately.',
			'Check desktop and mobile layout manually if screenshots are available. Fix spacing, contrast, alignment, navigation, and CTA issues before final response.',
			'Finish with the wp-admin auto-login link and, when useful, a shareable preview link.',
		],
		qualityBar: [
			'The first viewport must look intentionally designed, not like a starter theme.',
			'Every section should have a reason to exist and a different visual rhythm from the previous one.',
			'Buttons, navigation, headings, and image treatments must feel consistent.',
			'No lorem ipsum, no vague filler, no broken mobile layout, no invisible low-contrast text.',
		],
	};
}

export function registerDesignTools( server: McpServer ) {
	server.registerTool(
		'wpdev_site_design_brief',
		{
			description:
				'Create a structured design brief before building or redesigning a WordPress site. If the request is underspecified, this returns one scope question: empty site to iterate on later, or designed site now. Call this before wpdev_site_create for designed site builds unless the user only wants an empty test site. Use the returned referencePatterns for inspiration, but do not copy real websites. Follow the buildWorkflow and qualityBar while building.',
			inputSchema: {
				goal: z
					.string()
					.describe(
						'The user request or objective, including what the site is for and what outcome they want.'
					),
				siteName: z.string().optional().describe( 'Site or business name, if known.' ),
				context: z
					.string()
					.optional()
					.describe( 'Extra background, story, products, services, or personality.' ),
				audience: z.string().optional().describe( 'Primary audience or customer.' ),
				style: z
					.string()
					.optional()
					.describe( 'Preferred design style, mood, or visual direction.' ),
				pages: z
					.string()
					.optional()
					.describe( 'Requested pages or sections, separated by commas or new lines.' ),
			},
		},
		async ( input ) => {
			const brief = buildDesignBrief( input );
			const structuredContent = { brief };
			const nextInstruction =
				brief.siteSetupDecision.mode === 'clarify-first'
					? 'Ask the first question in questionsBeforeBuild and wait for the user answer before creating the site.'
					: brief.siteSetupDecision.mode === 'empty-site'
					? 'Create the empty WordPress site only. Do not add content, styling, plugins, or pages until the user asks to iterate.'
					: 'Follow this brief during site creation. Do not stop after creating an empty WordPress site.';

			return {
				content: [
					{
						type: 'text',
						text:
							`Design brief for ${ brief.siteName }:\n\n` +
							JSON.stringify( structuredContent, null, 2 ) +
							`\n\n${ nextInstruction }`,
					},
				],
				structuredContent,
			};
		}
	);
}
