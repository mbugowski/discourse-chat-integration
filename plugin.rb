# name: discourse-chat
# about: This plugin integrates discourse with a number of chat providers
# version: 0.1
# url: https://github.com/discourse/discourse-chat

enabled_site_setting :chat_enabled

after_initialize do

  module ::DiscourseChat
    PLUGIN_NAME = "discourse-chat".freeze

    class Engine < ::Rails::Engine
      engine_name DiscourseChat::PLUGIN_NAME
      isolate_namespace DiscourseChat
    end
  end

  require_relative "lib/provider"
  require_relative "lib/manager"

  DiscourseEvent.on(:post_created) do |post|
    if SiteSetting.chat_enabled?
      ::DiscourseChat::Manager.trigger_notifications(post.id)
    end
  end

  class ::DiscourseChat::ChatController < ::ApplicationController
    requires_plugin DiscourseChat::PLUGIN_NAME

    def respond
      render
    end

    def list_providers
      providers = ::DiscourseChat::Provider.providers.map {|x| {name: x::PROVIDER_NAME, id: x::PROVIDER_NAME}}
      render json:providers, root: 'providers'
    end

    def list_rules
      providers = ::DiscourseChat::Provider.providers.map {|x| x::PROVIDER_NAME}

      requested_provider = params[:provider]

      if requested_provider.nil?
        rules = DiscourseChat::Manager.get_all_rules()
      elsif providers.include? requested_provider
        rules = DiscourseChat::Manager.get_rules_for_provider(requested_provider)
      else
        raise Discourse::NotFound
      end

      render json: rules, root: 'rules'
    end

  end



  require_dependency 'admin_constraint'


  add_admin_route 'chat.menu_title', 'chat'

  DiscourseChat::Engine.routes.draw do
    get "" => "chat#respond"
    get '/providers' => "chat#list_providers"
    get '/rules' => "chat#list_rules"

    get "/:provider" => "chat#respond"
  end

  Discourse::Application.routes.append do
    mount ::DiscourseChat::Engine, at: '/admin/plugins/chat', constraints: AdminConstraint.new
  end

end