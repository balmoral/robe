require 'robe/common/state/atom'

class Todo < Robe::State::Atom
  attr :id, :text, :completed
end