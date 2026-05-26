import Config

# Per-environment overrides live in config/<env>.exs.
if File.exists?(Path.expand("#{config_env()}.exs", __DIR__)) do
  import_config "#{config_env()}.exs"
end
