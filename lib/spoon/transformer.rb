require "ast/node"
require "parslet"
require "spoon/util/ast_extensions"

module Spoon
  class Transformer < Parslet::Transform
    def reverse(expression)
      AST::Node.new(:op, [ "!", expression ], :operation => :prefix)
    end

    rule(:root => sequence(:expressions)) {
      AST::Node.new :root, expressions
    }

    rule(:block => simple(:expressions)) {
      AST::Node.new :block, [ expressions ]
    }

    rule(:block => sequence(:expressions)) {
      AST::Node.new :block, expressions
    }

    rule(:boolean => simple(:boolean)) {
      AST::Node.new :value, [ boolean.to_b ]
    }

    rule(:annotation => simple(:value)) {
      AST::Node.new :annotation, [ value ]
    }

    rule(:this => simple(:value)) {
      AST::Node.new :value, [ "this", value ], :is_this => true
    }

    rule(:self => simple(:value)) {
      AST::Node.new :value, [ "self", value ], :is_self => true
    }

    rule(:typed => { :value => simple(:value), :type => simple(:type) } ) {
      AST::Node.new :value, [ value, type ], :is_typed => true
    }

    rule(:class => { :name => simple(:name), :body => simple(:body) } ) {
      AST::Node.new :class, [ name, body ]
    }

    rule(:class => { :name => simple(:name), :extends => simple(:extends), :body => simple(:body) } ) {
      AST::Node.new :class, [ name, extends, body ], :is_extended => true
    }

    rule(:access => { :l => simple(:left), :r => simple(:right) }) {
      AST::Node.new :access, [ left, right ]
    }

    rule(:string => simple(:string)) {
      AST::Node.new :value, [ "'#{string}'" ]
    }

    rule(:string => sequence(:values)) {
      AST::Node.new :value, values, :is_interpolated => true
    }

    rule(:number => simple(:number)) {
      AST::Node.new :value, [ number.to_s ]
    }

    rule(:ident => simple(:value)) {
      AST::Node.new :value, [ value.to_v ], :is_ident => true
    }

    rule(:type => simple(:name)) {
      AST::Node.new :value, [ name ], :is_type => true
    }

    rule(:type => simple(:name), :generic => simple(:generic)) {
      AST::Node.new :value, [ name, generic ], :is_type => true, :is_generic => true
    }

    rule(:type => simple(:name), :generic => sequence(:generic)) {
      AST::Node.new :value, [ name ] + generic, :is_type => true, :is_generic => true
    }

    rule(:array => simple(:value)) {
      AST::Node.new :array, [ value ]
    }

    rule(:array => sequence(:values)) {
      AST::Node.new :array, values
    }

    rule(:hash => simple(:value)) {
      AST::Node.new :hash, [ value ]
    }

    rule(:hash => sequence(:values)) {
      AST::Node.new :hash, values
    }

    rule(:import => simple(:import)) {
      AST::Node.new :import, [ import ]
    }

    rule(:param => { :name => simple(:name) }) {
      AST::Node.new :param, [ name ]
    }

    rule(:param => { :name => simple(:name), :type => simple(:type) }) {
      AST::Node.new :param, [ type, name ], :is_typed => true
    }

    rule(:param => { :name => simple(:name), :value => simple(:value) }) {
      AST::Node.new :param, [ name, value ]
    }

    rule(:param => { :name => simple(:name), :type => simple(:type), :value => simple(:value) }) {
      AST::Node.new :param, [ type, name, value ], :is_typed => true
    }

    rule(:l => simple(:left), :o => simple(:op), :r => simple(:right)) {
      operator = op.to_op
      options = { :operation => :infix }

      if operator == "="
        options.store :is_assign, true
      elsif operator == "."
        options.store :is_chain, true
      end

      AST::Node.new :op, [ operator, left, right ], options
    }

    rule(:l => simple(:left), :o => simple(:op)) {
      AST::Node.new :op, [ op.to_op, left ], :operation => :suffix
    }

    rule(:o => simple(:op), :r => simple(:right)) {
      AST::Node.new :op, [ op.to_op, right ], :operation => :prefix
    }

    rule(:return => simple(:args)) {
      unless args == nil
        AST::Node.new :return, [ args ]
      else
        AST::Node.new :return
      end
    }

    rule(:construct => { :name => simple(:name) }) {
      AST::Node.new :new, [ name ]
    }

    rule(:construct => { :name => simple(:name), :args => simple(:args) }) {
      AST::Node.new :new, [ name, args ]
    }

    rule(:construct => { :name => simple(:name), :args => sequence(:args) }) {
      AST::Node.new :new, [ name ] + args
    }

    rule(:call => { :name => simple(:name) }) {
      AST::Node.new :call, [ name ]
    }

    rule(:call => { :name => simple(:name), :args => simple(:args) }) {
      AST::Node.new :call, [ name, args ]
    }

    rule(:call => { :name => simple(:name), :args => sequence(:args) }) {
      AST::Node.new :call, [ name ] + args
    }

    rule(:closure => { :body => simple(:body) }) {
      AST::Node.new :closure, [ body ]
    }

    rule(:closure => { :params => simple(:params), :body => simple(:body) }) {
      AST::Node.new :closure, [ params, body ]
    }

    rule(:closure => { :params => sequence(:params), :body => simple(:body) }) {
      AST::Node.new :closure, params + [ body ]
    }

    rule(:closure => { :type => simple(:type), :body => simple(:body) }) {
      AST::Node.new :closure, [ type, body ], :is_typed => true
    }

    rule(:closure => { :params => simple(:params), :type => simple(:type), :body => simple(:body) }) {
      AST::Node.new :closure, [ type, params, body ], :is_typed => true
    }

    rule(:closure => { :params => sequence(:params), :type => simple(:type), :body => simple(:body) }) {
      AST::Node.new :closure, [ type ] + params + [ body ], :is_typed => true
    }

    rule(:fat_closure => { :body => simple(:body) }) {
      AST::Node.new :closure, [ body ], :fat => true
    }

    rule(:fat_closure => { :params => simple(:params), :body => simple(:body) }) {
      AST::Node.new :closure, [ params, body ], :fat => true
    }

    rule(:fat_closure => { :params => sequence(:params), :body => simple(:body) }) {
      AST::Node.new :closure, params + [ body ], :fat => true
    }

    rule(:fat_closure => { :type => simple(:type), :body => simple(:body) }) {
      AST::Node.new :closure, [ type, body ], :is_typed => true, :fat => true
    }

    rule(:fat_closure => { :params => simple(:params), :type => simple(:type), :body => simple(:body) }) {
      AST::Node.new :closure, [ type, params, body ], :is_typed => true, :fat => true
    }

    rule(:fat_closure => { :params => sequence(:params), :type => simple(:type), :body => simple(:body) }) {
      AST::Node.new :closure, [ type ] + params + [ body ], :is_typed => true, :fat => true
    }

    rule(:if => { :condition => simple(:condition), :true => simple(:if_true) }) {
      AST::Node.new :if, [ condition, if_true ]
    }

    rule(:if => { :condition => simple(:condition), :true => simple(:if_true), :false => simple(:if_false) }) {
      AST::Node.new :if, [ condition, if_true, if_false ]
    }

    rule(:ifdef => { :condition => simple(:condition), :true => simple(:if_true) }) {
      AST::Node.new :ifdef, [ condition, if_true ]
    }

    rule(:ifdef => { :condition => simple(:condition), :true => simple(:if_true), :false => simple(:if_false) }) {
      AST::Node.new :ifdef, [ condition, if_true, if_false ]
    }

    rule(:unless => { :condition => simple(:condition), :true => simple(:if_true) }) {
      AST::Node.new :if, [ reverse(condition), if_true ]
    }

    rule(:unless => { :condition => simple(:condition), :true => simple(:if_true), :false => simple(:if_false) }) {
      AST::Node.new :if, [ reverse(condition), if_true, if_false ]
    }

    rule(:for => { :condition => simple(:condition), :body => simple(:body) }) {
      AST::Node.new :for, [ condition, body ]
    }

    rule(:while => { :condition => simple(:condition), :body => simple(:body) }) {
      AST::Node.new :while, [ condition, body ]
    }

    rule(:until => { :condition => simple(:condition), :body => simple(:body) }) {
      AST::Node.new :while, [ reverse(condition), body ]
    }
  end
end
