# frozen_string_literal: true

RSpec.describe Terradoc::Parser::HclLexer do
  subject(:lexer) { described_class.new }

  it "tokenizes basic HCL tokens and comments" do
    tokens = lexer.tokenize(<<~HCL)
      # resource comment
      resource "google_compute_instance" "web" { enabled = true }
    HCL

    types = tokens.map(&:type)
    expect(types).to include(:COMMENT, :IDENT, :STRING, :LBRACE, :EQUALS, :BOOL, :RBRACE, :NEWLINE, :EOF)

    comment = tokens.find { |token| token.type == :COMMENT }
    expect(comment.value).to eq("resource comment")
  end

  it "tokenizes heredoc as a single token" do
    tokens = lexer.tokenize(<<~HCL)
      locals {
        script = <<EOF
      echo hello
      EOF
      }
    HCL

    heredoc = tokens.find { |token| token.type == :HEREDOC }
    expect(heredoc).not_to be_nil
    expect(heredoc.value).to include("echo hello")
  end
end
