# frozen_string_literal: true

RSpec.describe Terradoc::Parser::HclParser do
  subject(:parser) { described_class.new }

  let(:ast_module) { Terradoc::Parser::AST }

  it "parses block structure, attributes, nested blocks, and references" do
    ast = parser.parse(<<~HCL)
      # web instance
      resource "google_compute_instance" "web" {
        machine_type = "e2-medium"
        zone = var.zone
        labels = {
          env = "prod"
        }

        boot_disk {
          initialize_params {
            image = "debian-cloud/debian-12"
          }
        }
      }
    HCL

    expect(ast.blocks.size).to eq(1)

    resource = ast.blocks.first
    expect(resource).to be_a(ast_module::Block)
    expect(resource.comment).to eq("web instance")
    expect(resource.type).to eq("resource")
    expect(resource.labels).to eq(%w[google_compute_instance web])

    attributes = resource.body.grep(ast_module::Attribute).to_h { |attribute| [attribute.key, attribute] }
    expect(attributes.fetch("machine_type").value).to eq(ast_module::Literal.new(value: "e2-medium"))
    expect(attributes.fetch("zone").value).to eq(ast_module::Reference.new(parts: %w[var zone]))

    labels_value = attributes.fetch("labels").value
    expect(labels_value).to be_a(ast_module::MapExpr)
    expect(labels_value.pairs.fetch("env")).to eq(ast_module::Literal.new(value: "prod"))

    boot_disk = resource.body.find { |item| item.is_a?(ast_module::Block) && item.type == "boot_disk" }
    expect(boot_disk).not_to be_nil

    initialize_params = boot_disk.body.find { |item| item.is_a?(ast_module::Block) && item.type == "initialize_params" }
    expect(initialize_params).not_to be_nil
  end

  it "parses conditional expressions and for expressions while preserving unsupported parts as RawExpr" do
    ast = parser.parse(<<~HCL)
      resource "google_compute_instance" "web" {
        count = var.enabled ? 1 : 0
        names = [for x in var.instances : x.name if x.enabled]
        complex = { for k, v in var.items : k => v if v.enabled }
      }
    HCL

    resource = ast.blocks.first
    attributes = resource.body.grep(ast_module::Attribute).to_h { |attribute| [attribute.key, attribute] }

    count_expr = attributes.fetch("count").value
    names_expr = attributes.fetch("names").value
    complex_expr = attributes.fetch("complex").value

    expect(count_expr).to be_a(ast_module::ConditionalExpr)
    expect(count_expr.cond).to eq(ast_module::Reference.new(parts: %w[var enabled]))
    expect(count_expr.true_val).to eq(ast_module::Literal.new(value: 1))
    expect(count_expr.false_val).to eq(ast_module::Literal.new(value: 0))

    expect(names_expr).to be_a(ast_module::ForExpr)
    expect(names_expr.is_map).to eq(false)
    expect(names_expr.key_var).to be_nil
    expect(names_expr.val_var).to eq("x")
    expect(names_expr.collection).to eq(ast_module::Reference.new(parts: %w[var instances]))
    expect(names_expr.body).to eq(ast_module::Reference.new(parts: %w[x name]))
    expect(names_expr.cond).to eq(ast_module::Reference.new(parts: %w[x enabled]))

    expect(complex_expr).to be_a(ast_module::ForExpr)
    expect(complex_expr.is_map).to eq(true)
    expect(complex_expr.key_var).to eq("k")
    expect(complex_expr.val_var).to eq("v")
    expect(complex_expr.collection).to eq(ast_module::Reference.new(parts: %w[var items]))
    expect(complex_expr.body).to be_a(ast_module::RawExpr)
    expect(complex_expr.body.text).to eq("k => v")
    expect(complex_expr.cond).to eq(ast_module::Reference.new(parts: %w[v enabled]))
  end
end
