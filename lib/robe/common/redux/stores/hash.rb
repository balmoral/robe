require 'robe/common/redux/store'

module Robe; module Redux
  class HashStore < Robe::Redux::Store
    include Enumerable

    # delegate read methods which do not affect state :
    #   if the corresponding Array method would return a new Array
    #   then so will the method here
    read_state(*%w(
      [] < <= > >=
      any? assoc
      compare_by_identity compare_by_identity?
      dig
      each each_key each_pair each_value empty? eql?
      fetch fetch_values flatten
      has_key? has_value? hash
      include? inspect
      key key? keys
      length member? merge
      rassoc size value? values values_at
      to_a to_s to_h to_hash
    ).map(&:to_sym))

    # reduce methods / actions which change state
    # but require a duplicate of the state to be made in
    # generated reducer before calling the mutate method
    # on the new state
    reduce_dup(*%w(
      []=
      clear compact delete delete_if
      invert keep_if
      merge!
      rehash reject replace select
      update
    ).map(&:to_sym))

    def initialize(initial = {}, &block)
      super(initial, &block)
    end

  end
end end

