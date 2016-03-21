require 'spec_helper'

describe Spoon::Parser do
  let(:parser) { Spoon::Parser.new }

  context "chain parsing" do
    subject { parser.chain }

    it { should parse "a.b.c" }
    it { should parse "a().b().c(d, e).f" }
    it { should_not parse "a b.c" }
  end

  context "comment parsing" do
    subject { parser.comment }

    it { should parse "# comment" }
    it { should parse "#comment" }
    it { should_not parse "# comment\n expression" }
  end

  context "condition parsing" do
    subject { parser.condition }

    it { should parse "if (something) anything" }
    it { should parse "if (a) b else if (c) d else e" }
    it { should_not parse "if a b c" }
    it { should_not parse "if (something) a b" }
  end

  context "function parsing" do
    subject { parser.function }

    it { should parse "def test() it" }
    it { should parse "def test it" }
    it { should parse "def test(me = 1) it" }
    it { should parse "def test me = 2 it" }
    it { should_not parse "def test() me it" }
    it { should_not parse "def test me it he" }
  end

  context "name parsing" do
    subject { parser.name }

    it { should parse "a-b-c" }
    it { should parse "abcdef" }
    it { should parse "a" }
    it { should_not parse "ab=" }
    it { should_not parse "a2b" }
    it { should_not parse "ab_cd" }
  end

  context "number parsing" do
    subject { parser.number }

    it { should parse "123456789" }
    it { should parse "1.2" }
    it { should_not parse "a2" }
  end
end
