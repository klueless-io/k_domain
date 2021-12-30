# Domain Simple

This folder contains the inputs and outputs for a relative simple domain with about 15 models

These models have cardinality representations including `1-1`, `1-many` and `many-many`

`sample.rb` is the only model with lots of usecases on it.

## Create Routes Input File

Run rails

```bash
rails server
```

NOTE: I had to run each line one at a time


```ruby
    # alias:          r.name,
    # path:           r.path.spec.to_s,
    # verb:           r.constraints[:request_method],
    # controller:     r.defaults[:controller],
    # action:         r.defaults[:action],
    # extra:          r.defaults.except(:controller, :action)

routes = Rails.application.routes.routes.map do |r|
  {
    alias:          r.name,
    path:           r.path.spec.to_s,
    verb:           r.constraints[:request_method],
    controller:     r.defaults[:controller],
    action:         r.defaults[:action],
    extra:          r.defaults.except(:controller, :action)
  }
end

File.write('a.txt', { routes: routes }.to_json)
```
