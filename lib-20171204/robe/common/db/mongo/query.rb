# https://docs.mongodb.com/manual/reference/operator/query/
#
# COMPARISON
# ----  -------------------------
# Name	Description
# ----  -------------------------
# $eq	  Matches values that are equal to a specified value.
# $gt	  Matches values that are greater than a specified value.
# $gte	Matches values that are greater than or equal to a specified value.
# $lt	  Matches values that are less than a specified value.
# $lte	Matches values that are less than or equal to a specified value.
# $ne   Matches all values that are not equal to a specified value.
# $in   Matches any of the values specified in an array.
# $nin	Matches none of the values specified in an array.
#
# LOGICAL
# ----  -------------------------
# Name	Description
# ----  -------------------------
# $or	  Joins query clauses with a logical OR    : returns all documents that match the conditions of either clause.
# $and	Joins query clauses with a logical AND   : returns all documents that match the conditions of both clauses.
# $not	Inverts the effect of a query expression : returns documents that do not match the query expression.
# $nor	Joins query clauses with a logical NOR   : returns all documents that fail to match both clauses.
#
# EG
#
# db.inventory.find( { qty: { $gte: 20 } } )
#
# db.inventory.update( { "carrier.fee": { $gte: 2 } }, { $set: { price: 9.99 } } )
#
# db.inventory.find( { $and: [ { price: { $ne: 1.99 } }, { price: { $exists: true } } ] } )
#
# db.inventory.find( { qty: { $nin: [ 5, 15 ] } } )
#
# db.inventory.find( { $or: [ { quantity: { $lt: 20 } }, { price: 10 } ] } )
#
# DB.bars.find(symbol: 'AAPL', $and => [{date: {$gte => '20150615'}}, {date: {$lte => '20150618'}} ])
#
# db.inventory.find( {
#   $and : [
#       { $or : [ { price : 0.99 }, { price : 1.99 } ] },
#       { $or : [ { sale : true }, { qty : { $lt : 20 } } ] }
#     ]
# } )
#
# REGEX SYNTAX
# { <field>: { $regex: /pattern/, $options: '<options>' } }
# { <field>: { $regex: 'pattern', $options: '<options>' } }
# { <field>: { $regex: /pattern/<options> } }
#
# REGEX EG
# { name: { $in: [ /^acme/i, /^ack/ ] } }
# { name: { $regex: /acme.*corp/i, $nin: [ 'acmeblahcorp' ] } }
# { name: { $regex: /acme.*corp/, $options: 'i', $nin: [ 'acmeblahcorp' ] } }
# { name: { $regex: 'acme.*corp', $options: 'i', $nin: [ 'acmeblahcorp' ] } }
#
# REGEX REF
# http://docs.mongodb.org/manual/reference/operator/query/regex/#op._S_regex
#
# TODO: implement all query operators:
# ref: https://docs.mongodb.com/manual/reference/operator/query/
#
# Robe::Mongo::Query allows easy construction of queries.
#
# Examples:
#
# include Robe::Mongo::Query
#
# _and( _eq(:name, 'Fred'), _eq(:dob, '19991231'))
# => {"$and"=>[{"name"=>{"$eq"=>"Fred"}}, {"dob"=>{"$eq"=>"19991231"}}]}

module Robe; module Mongo
  module Query
    module_function

    OPS = {
      comparison: {
        unary: {
          :_eq      => '$eq',
          :_ne      => '$ne',
          :_gt      => '$gt',
          :_gte     => '$gte',
          :_lt      => '$lt',
          :_lte     => '$lte'
        },
        n_ary: {
          :_in      => '$in',
          :_nin     => '$nin'
        }
      },
      logical: {
        unary: {
          :_not     => '$not',
        },
        n_ary: {
          :_and     => '$and',
          :_or      => '$or',
          :_nor     => '$nor'
        }
      },
      regex: {
        :_regex => '$regex'
      }
    }

    OPS[:comparison][:unary].each do |op, op_s|
      define_method op do | **kwargs |
        unless kwargs.size > 0
          raise ArgumentError, "#{op} requires at least one keyword argument"
        end
        result = kwargs.map do |field, value|
          unless value.respond_to?(:to_s)
            raise ArgumentError, "#{op} requires operand which responds to #to_s"
          end
          { field.to_s => { [op_s] => value.to_s } }
        end
        result.size == 1 ? result.first : _and(*result)
      end
    end

    OPS[:logical][:unary].each do |op, op_s|
      define_method op do |*hashables|
        unless args.size > 0
          raise ArgumentError, "#{op} requires at least one argument"
        end
        hashables = args.map { |hashable|
          unless hashable.respond_to?(:to_h)
            raise ArgumentError, "#{op} requires operand which responds to #to_h"
          end
          { op_s => hashable.to_h }
        }
        hashables.size == 1 ? hashables.first : _and(*hashables)
      end
    end

    OPS[:comparison][:n_ary].each do |op, op_s|
      define_method op do |**kwargs|
        unless kwargs.size > 0
          raise ArgumentError, "#{op} requires at least one keyword argument"
        end
        result = kwargs.map do |field, values|
          values = [values] unless values.is_a?(Array)
          values = values.map { |value|
            unless value.respond_to?(:to_s)
              raise ArgumentError, "#{op} requires operands which responds to #to_s"
            end
            value.to_s
          }
          { field.to_s => { [op_s] => values } }
        end
        result.size == 1 ? result.first : _and(*result)
      end
    end

    OPS[:logical][:n_ary].each do |op, op_s|
      define_method op do |*hashables|
        unless args.size > 0
          raise ArgumentError, "#{op} requires at least one argument"
        end
         hashables = hashables.map { |hashable|
          unless hashable.respond_to?(:to_h)
            raise ArgumentError, "#{op} requires operands which responds to #to_h"
          end
          hashable.to_h
        }
        { op_s => hashables }
      end
    end

    # REGEX EXPRESSION
    def _regex(field, pattern, options = nil)
      r = { '$regex' => pattern.to_s }
      r['$options'] = options.to_s if options
      { field.to_s =>  r }
    end

  end
end end



