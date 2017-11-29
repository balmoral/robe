class TodoApp < Robe::Client::App
  class Index < Robe::Client::Component
    # router is provided by base component class
    def render
      div.style(margin_top: 1.em)[
        # whenever the route changes update the index
        bind(router) {
          # and whenever the TODOS change update the list
          div[
            bind(TODOS) {
              TODOS.all.map { |todo|
                # if done state not in scope then give a nil
                bind(todo, :done) {
                  if app.done_states.include?(todo.done)
                    todo_item(todo)
                  end
                }
              }
            }
          ]
        }
      ]
    end

    def todo_item(todo)
      div.style(margin_bottom: 1.em)[
        todo_text(todo),
        todo_done(todo),
        todo_delete(todo),
      ]
    end

    def todo_text(todo)
      input
      .value(todo.text)
      .style(width: 30.em)
      .on(
        input: ->(event) {
          todo.mutate!(text: event.target.value)
        }
      )
    end

    def todo_done(todo)
      input
      .type(:checkbox)
      .checked(todo.done)
      .style(margin_left: 2.em)
      .on(
        click: ->{
          todo.mutate!(done: !todo.done)
        }
      )
    end

    def todo_delete(todo)
      button['X']
      .style(color: :red, font_size: :smaller, margin_left: 2.em)
      .on(
        click: ->{
          TODOS.delete(todo)
        }
      )
    end
  end
end