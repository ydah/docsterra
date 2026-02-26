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
    expect(resource.labels).to eq(["google_compute_instance", "web"])

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

  it "falls back to RawExpr for unsupported complex expressions" do
    ast = parser.parse(<<~HCL)
      resource "google_compute_instance" "web" {
        count = var.enabled ? 1 : 0
        complex = { for k, v in var.items : k => v if v.enabled }
      }
    HCL

    resource = ast.blocks.first
    attributes = resource.body.grep(ast_module::Attribute).to_h { |attribute| [attribute.key, attribute] }

    count_expr = attributes.fetch("count").value
    complex_expr = attributes.fetch("complex").value

    expect(count_expr).to be_a(ast_module::RawExpr)
    expect(count_expr.text).to eq("var.enabled ? 1 : 0")

    expect(complex_expr).to be_a(ast_module::RawExpr)
    expect(complex_expr.text).to include("for k, v in var.items")
  end
end
