---
name: claude-md
description: Write or update a CLAUDE.md file for a project. Use when the user asks to create, write, update, or improve a CLAUDE.md or project memory file.
allowed-tools: Read, Write, Edit, Glob, Grep
---

# Writing CLAUDE.md Files

Create concise, actionable project context files that Claude reads on every interaction.

## Key Principles

1. **Concise** - Every line costs tokens on every request. Target 60-150 lines.
2. **Bullet points** - Scannable, not verbose narratives
3. **Actionable** - Commands, patterns, conventions - not explanations
4. **Progressive disclosure** - Reference other files with `@path/to/file` syntax
5. **No linting rules** - Use actual linters instead (ESLint, Prettier, etc.)

## Recommended Structure

```markdown
# Project Name

One-line description of what this project does.

## Tech Stack

- **Primary language/framework** - version if relevant
- **Key dependencies** - only the important ones
- **Build tools** - what builds/runs the project

## Project Structure

Brief overview of key directories. Use a small tree or bullet list.

## Common Commands

- `command` - What it does
- `command` - What it does

## Conventions

- Naming patterns
- Import style
- Architecture patterns
- Testing approach

## Do Not Modify

- Files that shouldn't be touched
- Generated files
- Security-sensitive areas
```

## What to Include

- Tech stack and versions
- Project structure (key directories only)
- Common commands (build, test, run, deploy)
- Code conventions and patterns
- File/directory restrictions
- References to detailed docs with `@path/to/doc.md`

## What to Avoid

- Code style rules (use linters)
- Long explanations (use bullet points)
- Duplicating README content
- Auto-generated content
- Task-specific details (use `.claude/rules/` instead)
- Code examples (reference files instead)

## File Hierarchy

Claude supports multiple memory files (highest priority first):

| File | Scope |
|------|-------|
| `CLAUDE.local.md` | Personal overrides (gitignored) |
| `.claude/CLAUDE.md` | Project instructions |
| `CLAUDE.md` | Project root |
| `~/.claude/CLAUDE.md` | Personal global |

For large projects, use `.claude/rules/*.md` for topic-specific rules.

## Path-Scoped Rules

Use YAML frontmatter to scope rules to specific paths:

```yaml
---
paths:
  - "src/api/**/*.ts"
---

# API-specific instructions here
```

## Process

1. **Explore** - Understand the project structure, tech stack, and conventions
2. **Identify** - Find existing CLAUDE.md or determine if creating new
3. **Draft** - Write concise, bullet-point content
4. **Review** - Ensure under 150 lines, no redundancy
5. **Reference** - Link to detailed docs rather than embedding

## Updating Existing Files

When updating:
- Preserve existing structure if it works
- Add new sections rather than rewriting
- Remove outdated information
- Keep line count in check
