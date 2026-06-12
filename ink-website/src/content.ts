export const GITHUB_URL = 'https://github.com/Cloverings1/Ink'

export const features = [
  {
    title: 'Zero friction',
    description:
      'Global hotkey opens the panel instantly. No context switch, no Dock icon required. Dismiss with Esc.',
    keys: ['⌥', '⌘', 'N'],
  },
  {
    title: 'Native floating panel',
    description:
      'Built on NSPanel with nonactivating behavior — floats above your work without stealing app activation.',
  },
  {
    title: 'Plain Markdown',
    description:
      'Raw Markdown with a toolbar that inserts syntax. What you see is exactly what lives on disk.',
  },
  {
    title: 'Files you own',
    description:
      'Notes are individual .md files in a folder you choose. Open them in Obsidian, VS Code, BBEdit, or git.',
  },
  {
    title: 'Customizable shortcuts',
    description:
      'Create, browse, and command palette — all remappable through KeyboardShortcuts.',
    keys: ['⌥', '⌘', 'P'],
  },
  {
    title: 'Instant search',
    description:
      'In-memory title and content index for fast browse and search. No database lock-in.',
  },
] as const

export const steps = [
  {
    step: '01',
    title: 'Summon from anywhere',
    body: 'Press ⌥⌘N while coding, browsing, or in fullscreen. The frosted panel appears in milliseconds.',
  },
  {
    step: '02',
    title: 'Write in Markdown',
    body: 'Type raw Markdown with toolbar inserts for bold, headings, lists, and more. No WYSIWYG layer.',
  },
  {
    step: '03',
    title: 'Own your files',
    body: 'Every note auto-saves as note-<UUID>.md in your notes folder. Open, sync, and version them anywhere.',
  },
] as const

export const roadmapItems = [
  'Signed and notarized public release builds',
  'Optional syntax highlighting for raw Markdown',
  'Theme controls that keep the panel native',
  'File-watching for edits made in other apps',
  'Import/export polish for larger note collections',
] as const
