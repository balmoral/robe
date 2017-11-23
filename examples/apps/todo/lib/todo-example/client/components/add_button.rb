class TodoApp < Robe::Client::App
  class AddButton < Robe::Client::Component
    def render
      button['Add todo...'].on(
        click: ->{
          add_todo
        }
      )
    end

    def add_todo
      TODOS << Todo.new(id: TODOS.size, text: "Todo ##{TODOS.size}", completed: false)
    end
  end
end