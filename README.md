# Docsterra

`docsterra` is a Ruby gem / CLI that parses Terraform (`.tf`) files and generates infrastructure design documentation in Markdown.

Current implementation focuses on GCP Terraform resources and produces:

- resource inventory tables
- Mermaid network diagrams
- cross-product dependency diagrams
- security summaries (IAM / firewall / warnings)
- cost-related spec summaries (non-billing estimate metadata)

## Installation

```bash
gem install docsterra
```

Or from a Gemfile:

```ruby
gem "docsterra"
```

## Quick Start

Single Terraform root:

```bash
docsterra generate ./terraform
```

Multiple products (cross-product dependency analysis enabled):

```bash
docsterra generate ./product-a/terraform ./product-b/terraform ./shared/terraform -o ./docs/infrastructure.md
```

Dry-run summary:

```bash
docsterra check ./terraform
```

## CLI Reference

### Commands

```bash
docsterra generate [PATHS...]
docsterra check [PATHS...]
docsterra version
```

### Options

- `-o`, `--output`: output markdown path (default: `./infrastructure.md`)
- `-c`, `--config`: config file path (default: `.docsterra.yml`)
- `-s`, `--sections`: comma-separated sections (`all`, `resources`, `network`, `security`, `cost`)
- `-f`, `--format`: output format (currently only `markdown`)
- `-v`, `--verbose`: verbose output
- `--ignore`: ignore glob patterns (repeatable via Thor array syntax)

## Library Usage

```ruby
require "docsterra"

doc = Docsterra.generate("./terraform")
doc.save("./docs/infrastructure.md")
puts doc.to_markdown

summary = Docsterra.check("./terraform")
puts summary[:resource_count]
```

## Configuration (`.docsterra.yml`)

```yaml
products:
  - name: "Web Application"
    path: "./product-web/terraform"
  - name: "Shared Infrastructure"
    path: "./shared/terraform"
    shared: true

output:
  path: "./docs/infrastructure.md"
  sections:
    - resources
    - network
    - security
    - cost

resource_attributes:
  google_compute_instance:
    - machine_type
    - zone
    - labels.env

ignore:
  - "**/examples/**"
```

## Output Example (Sections)

- `## Overview`
- `## Cross-Product Dependencies` (Mermaid)
- `## {Product}`
- `### Resources`
- `### Network Configuration` (Mermaid)
- `### Security Settings`
- `### Cost Estimation`
- `## Appendix`

## Limitations

- HCL parsing is best-effort. Unsupported expressions are preserved as `RawExpr` and rendered as text.
- Remote modules are not parsed (metadata only).
- Local modules are parsed recursively, but complex module evaluation/output resolution is not performed.
- No real-time GCP pricing lookup; cost output is resource spec metadata only.
- Terraform state / `terraform plan` JSON is not consumed.

## Development

```bash
bundle install
bundle exec rspec
```

## License

MIT
