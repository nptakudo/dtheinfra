# Documentation Guide

This project uses [Mintlify](https://mintlify.com) for documentation publishing. The documentation is organized as a monorepo with all content under version control.

## Documentation Structure

```
dtheinfra/
├── mint.json                    # Mintlify configuration
├── README.md                    # Project overview (homepage)
├── docs/                        # Main documentation
│   ├── architecture/            # Architecture guides and ADRs
│   ├── development/             # Developer guides
│   └── operations/              # Operational procedures
├── infra/                       # Infrastructure component docs
│   ├── QUICKSTART.md           # Quick start guide
│   ├── COMPONENT_PATTERN.md    # Component standards
│   └── [component]/README.md   # Individual component docs
└── logo/                        # Branding assets
    ├── light.svg
    ├── dark.svg
    └── favicon.svg
```

## Local Development

### Prerequisites

Install Mintlify CLI:
```bash
npm i -g mintlify
```

### Preview Documentation

Run the development server:
```bash
mintlify dev
```

Open [http://localhost:3000](http://localhost:3000) in your browser.

### Build for Production

```bash
mintlify build
```

## Publishing

Documentation is automatically deployed to Mintlify when changes are pushed to the `mintlify` branch.

### Setup Mintlify Hosting

1. Go to [Mintlify Dashboard](https://dashboard.mintlify.com)
2. Connect your GitHub repository
3. Configure deployment settings:
   - Branch: `mintlify` (or `main`)
   - Build command: Auto-detected
   - Output directory: Auto-detected

## Adding New Pages

1. Create a new Markdown file in the appropriate directory:
   ```bash
   # For architecture docs
   touch docs/architecture/new-guide.md

   # For infrastructure components
   touch infra/component-name/README.md
   ```

2. Add the page to `mint.json` navigation:
   ```json
   {
     "group": "Architecture",
     "pages": [
       "docs/architecture/new-guide"
     ]
   }
   ```

3. Preview changes locally with `mintlify dev`

## Documentation Best Practices

### Markdown Files

- Use clear, descriptive titles
- Include a brief introduction paragraph
- Use headings to structure content (H2, H3)
- Add code examples with proper syntax highlighting
- Include diagrams using Mermaid

### Mermaid Diagrams

Mintlify supports Mermaid diagrams natively:

\`\`\`mermaid
graph LR
    A[Start] --> B[Process]
    B --> C[End]
\`\`\`

### Code Blocks

Use syntax highlighting for code blocks:

\`\`\`python
def hello():
    print("Hello, World!")
\`\`\`

### Internal Links

Link to other documentation pages:
```markdown
See the [Getting Started Guide](/docs/development/getting-started)
```

## Configuration

The `mint.json` file controls:
- Navigation structure
- Branding (logo, colors)
- Features (search, dark mode, feedback)
- Social links
- Metadata

## Troubleshooting

### Local Preview Not Working

1. Check Node.js version: `node --version` (requires Node 14+)
2. Reinstall Mintlify: `npm i -g mintlify`
3. Clear cache: `rm -rf .mintlify`

### Missing Pages

Verify the file path in `mint.json` matches the actual file location (without `.md` extension).

### Broken Links

Run link checking:
```bash
mintlify broken-links
```

## Resources

- [Mintlify Documentation](https://mintlify.com/docs)
- [Mintlify GitHub](https://github.com/mintlify/mint)
- [Markdown Guide](https://www.markdownguide.org/)
- [Mermaid Docs](https://mermaid.js.org/)
