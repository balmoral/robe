require 'robe/common/redux/store'

module Robe; module Redux
  class ArrayStore < Robe::Redux::Store
    include Enumerable

    # Read-only methods which are delegated to the state.
    # If the corresponding Array method would return
    # a new Array then so will the method here.
    read_state(*%w(
      [] & | * + - <=> ==
      any? assoc at
      bsearch bsearch_index
      collect compact count cycle
      detect dig
      each each_cons each_entry each_slice each_with_index each_with_object
      empty? eql?
      fetch find find_all find_index first
      flatten flat_map group_by
      hash include? index inject inspect
      join last lazy length
      map max max_by member? min min_by minmax minmax_by
      none? one?
      pack partition
      rassoc reduce reject reverse reverse_each r_index rotate
      sample select shuffle slice size sort sum
      take take_while transpose
      to_a to_ary to_h to_s
      uniq values_at zip
    ).map(&:to_sym))

    # Reduce methods / actions which change state
    # requiring a duplicate of the state to be made in
    # the reducer before calling the mutate method
    # on the new state.
    reduce_dup(*%w(
      << []=
      clear compact! concat collect!
      delete delete_at delete_if drop drop_while
      fill
      initialize_copy insert
      map!
      permutation pop prepend push
      reject! replace reverse! reverse_each rotate!
      sample select! shift shuffle! slice!
      sort! sort_by! sum
      take take_while
      uniq! unshift
    ).map(&:to_sym))

    def initialize(initial_array = [], &block)
      super(initial_array, &block)
    end

  end
end end

