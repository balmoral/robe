require 'todo-example/common/todo'
require 'todo-example/client/components/header'
require 'todo-example/client/components/add_button'
require 'todo-example/client/components/index'
require 'todo-example/client/components/footer'

class TodoApp < Robe::Client::App
  class Page < Robe::Client::Component
    def render
      div.style(margin_left: 2.em)[
        Header.new,
        AddButton.new,
        Index.new,
        Footer.new
      ]
    end
  end
end