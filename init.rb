require 'redmine'
require_dependency 'advise_hooks'

Redmine::Plugin.register :advise do
  name 'Advise plugin'
  author 'Damien GILLES'
  description "Find the closest related tickets"
  version '0.1'
  settings partial: 'settings/advise', default: {}
  project_module 'advise' do
    permission :advise, :public => true
  end
end