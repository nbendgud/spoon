module Spoon
  class Compiler
    attr_reader :name

    def initialize(path = "main")
      basename = File.basename(path, ".*")
      @name = basename.split('_').collect!{ |w| w.capitalize }.join

      @nodes = {
        :root => Root,
        :block => Block,
        :function => Function,
        :closure => Closure,
        :if => If,
        :for => For,
        :while => While,
        :op => Operation,
        :call => Call,
        :return => Return,
        :import => Import,
        :param => Param,
        :value => Value
      }

      @namespace = []
    end

    def namespace_new
      @namespace.push Hash.new
    end

    def namespace_pop
      @namespace.pop
    end

    def namespace_current
      @namespace.last
    end

    def namespace_contains(key)
      @namespace.each do |namespace|
        return true if namespace.key?(key)
      end

      false
    end

    def compile(node, parent = nil, tab = "")
      @nodes[node.type].new(self, node, parent, tab).compile.to_s
    end
  end

  class Base
    attr_reader :tab
    attr_reader :node
    attr_reader :parent

    def initialize(compiler, node, parent, tab)
      @compiler = compiler
      @node = node
      @parent = parent
      @content = ""
      @tab = tab
    end

    def compile
      @content
    end

    def compile_next(node)
      @compiler.compile(node, self, @tab)
    end

    def compile_str(str)
      if str.start_with? "'"
        str
      else
        str.gsub!("-", "_") || str
      end
    end
  end

  class Root < Base
    def initialize(compiler, node, parent, tab)
      super
      @tab = "    "
    end

    def compile
      @compiler.namespace_new
      @compiler.namespace_current[@compiler.name] = true

      imports = ""
      @content << "class #{@compiler.name} {\n"
      @content << "  static public function main() {\n"

      @node.children.each do |child|
        if child.type == :import
          imports << compile_next(child) << ";\n"
        else
          @content << @tab << compile_next(child) << ";\n"
        end
      end

      @content = "#{imports}\n#{@content}"
      @content << "  }\n"
      @content << "}"

      @compiler.namespace_pop
      super
    end
  end

  class Block < Base
    def initialize(compiler, node, parent, tab)
      super
      @tab = tab + "  "
    end

    def compile
      @content << "{\n"

      @node.children.each do |child|
        @content << @tab << compile_next(child) << ";\n"
      end

      @content << @parent.tab << "}"
      super
    end
  end

  class Operation < Base
    def compile
      children = @node.children.dup
      operator = children.shift.to_s

      @content << "(" if @parent.node.type == :op

      case @node.option :operation
      when :infix
        left = children.shift

        if left.type == :value && operator == "="
          namespace = @compiler.namespace_current
          name = compile_next(left)

          unless @compiler.namespace_contains name
            namespace[name] = true
            @content << "var "
          end
        end

        @content << compile_next(left)
        @content << " #{operator} "
        @content << compile_next(children.shift)
      when :prefix
        @content << operator
        @content << compile_next(children.shift)
      when :suffix
        @content << compile_next(children.shift)
        @content << operator
      end

      @content << ")" if @parent.node.type == :op

      super
    end
  end

  class Value < Base
    def compile
      children = @node.children.dup
      interpolated = children.length > 1

      if interpolated
        children.each do |child|
          if child.is_a? String
            @content << child.to_s
          else
            @content << compile_next(child)
          end

          @content << " + " unless children.last == child
        end
      else
        content = @node.children.dup.shift.to_s
        @content << compile_str(content)
      end
      super
    end
  end

  class Param < Base
    def compile
      children = @node.children.dup
      @content << children.shift.to_s
      @content << " = " << compile_next(children.shift) unless children.empty?
      super
    end
  end

  class Call < Base
    def compile
      children = @node.children.dup
      @content << compile_str(children.shift.to_s)
      @content << "("

      children.each do |child|
        @content << compile_next(child)
        @content << ", " unless children.last == child
      end

      @content << ")"
      super
    end
  end

  class Import < Base
    def compile
      children = @node.children.dup

      @content << "import "

      children.each do |child|
        @content << compile_next(child)
        @content << "." unless children.last == child
      end

      super
    end
  end

  class Function < Base
    def compile
      @compiler.namespace_new

      children = @node.children.dup
      name = compile_str(children.shift.to_s)

      @content << "function #{name}("

      if children.length > 1
        children.each do |child|
          name = child.children.first.to_s
          @compiler.namespace_current[name] = true unless @compiler.namespace_contains name

          unless child == children.last
            @content << compile_next(child)
            @content << ", " unless child == children[children.length - 2]
          end
        end
      end

      @content << ") "
      @content << compile_next(children.last)

      @compiler.namespace_pop
      super
    end
  end

  class Closure < Base
    def compile
      @compiler.namespace_new

      children = @node.children.dup

      @content << "function ("

      if children.length > 1
        children.each do |child|
          name = child.children.first.to_s
          @compiler.namespace_current[name] = true unless @compiler.namespace_contains name

          unless child == children.last
            @content << compile_next(child)
            @content << ", " unless child == children[children.length - 2]
          end
        end
      end

      @content << ") "
      @content << compile_next(children.last)

      @compiler.namespace_pop
      super
    end
  end

  class If < Base
    def compile
      children = @node.children.dup

      @content << "if (" << compile_next(children.shift) << ") "
      @content << compile_next(children.shift)
      @content << " else " << compile_next(children.shift) unless children.empty?
      super
    end
  end

  class For < Base
    def compile
      children = @node.children.dup

      @content << "for (" << compile_next(children.shift) << ") "
      @content << compile_next(children.shift)
      super
    end
  end

  class While < Base
    def compile
      children = @node.children.dup

      @content << "while (" << compile_next(children.shift) << ") "
      @content << compile_next(children.shift)
      super
    end
  end

  class Return < Base
    def compile
      children = @node.children.dup
      multi = children.length > 1
      @content << "return "
      @content << "[" if multi

      children.each do |child|
        @content << compile_next(child)
        @content << ", " unless children.last == child
      end

      @content << "]" if multi

      super
    end
  end
end
