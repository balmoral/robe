class TodoApp < Robe::Client::App
  class AddButton < Robe::Client::Component
    def render
      button['Add todo...'].css(:button).on(click: ->{ TODOS.add })
    end

  end
end