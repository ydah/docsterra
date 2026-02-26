# Changelog

## [0.1.0] - 2026-02-26

- Initial implementation of `terradoc`
- HCL lexer/parser with `RawExpr` fallback for unsupported expressions
- Resource registry and local module resolver
- Project/resource models and analyzers (resource/network/security/dependency/cost)
- Markdown and Mermaid renderers
- CLI (`generate`, `check`, `version`) and top-level integration pipeline
- RSpec test suite with fixtures for parser, analyzers, renderers, and E2E generation
