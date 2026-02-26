# Terradoc

`terradoc` is a Ruby gem / CLI that parses Terraform (`.tf`) files and generates infrastructure design documentation in Markdown.

Current implementation focuses on GCP Terraform resources and produces:

- resource inventory tables
- Mermaid network diagrams
- cross-product dependency diagrams
- security summaries (IAM / firewall / warnings)
- cost-related spec summaries (non-billing estimate metadata)

## Installation

```bash
gem install terradoc
```

Or from a Gemfile:

```ruby
gem "terradoc"
```

## Quick Start

Single Terraform root:

```bash
terradoc generate ./terraform
```

Multiple products (cross-product dependency analysis enabled):

```bash
terradoc generate ./product-a/terraform ./product-b/terraform ./shared/terraform -o ./docs/infrastructure.md
```

Dry-run summary:

```bash
terradoc check ./terraform
```

## CLI Reference

### Commands

```bash
terradoc generate [PATHS...]
terradoc check [PATHS...]
terradoc version
```

### Options

- `-o`, `--output`: output markdown path (default: `./infrastructure.md`)
- `-c`, `--config`: config file path (default: `.terradoc.yml`)
- `-s`, `--sections`: comma-separated sections (`all`, `resources`, `network`, `security`, `cost`)
- `-f`, `--format`: output format (currently only `markdown`)
- `-v`, `--verbose`: verbose output
- `--ignore`: ignore glob patterns (repeatable via Thor array syntax)

## Library Usage

```ruby
require "terradoc"

doc = Terradoc.generate("./terraform")
doc.save("./docs/infrastructure.md")
puts doc.to_markdown

summary = Terradoc.check("./terraform")
puts summary[:resource_count]
```

## Configuration (`.terradoc.yml`)

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

- `## 概要`
- `## プロダクト間依存関係` (Mermaid)
- `## {Product}`
- `### リソース一覧`
- `### ネットワーク構成` (Mermaid)
- `### セキュリティ設定`
- `### コスト概算情報`
- `## 付録`

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
bundle exec rubocop
```

If `rubocop` cache path is restricted in your environment, use:

```bash
RUBOCOP_CACHE_ROOT=/tmp/rubocop-cache bundle exec rubocop
```

## License

MIT
