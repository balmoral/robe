class TodoApp < Robe::Client::App
  class Footer < Robe::Client::Component
    def render
      bind(router) {
        div[
          bind(TODOS) {
            if TODOS.size > 1
              div[
                button_link('all'),
                button_link('active'),
                button_link('completed')
              ]
            end
          }
        ]
      }
    end

    # A `link` sets the client-side router state
    # and updates the browser history. Use links
    # in place of anchor tags to prevent the
    # browser doing getting url from the server.
    def button_link(which)
      link.href("/#{which}")[
        button
        .disabled(app.completed_scope == which)
        .style(margin_right: 1.em, width: 6.em)[
          which.to_s.capitalize
        ]
      ]
    end
  end
end