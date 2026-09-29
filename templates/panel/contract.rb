Dovetail.contract(:{{module}}, version: 1) do
  type :item do
    field :label, String
  end
  operation :items, input: {}, output: list(:item)
  panel do
    slot :main, size: :main
    view :overview, data: :items, states: %i[loading empty error unavailable ready]
    capability :navigation
    route '{{namespace}}'
    tokens :default
  end
end
