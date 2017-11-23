class TodoApp < Robe::Client::App
  class Header < Robe::Client::Component
    def render
      h1.style(margin_bottom: 1.em)[
        'RoBE Todos'
      ]
    end
  end
end