module ForemanAzureRM
  class Engine < ::Rails::Engine
    engine_name 'foreman_azure_rm'

    #autoloading all files inside lib dir
    config.eager_load_paths += Dir["#{config.root}/lib"]
    config.eager_load_paths += Dir["#{config.root}/app/models/concerns/foreman_azure_rm/vm_extensions/"]

    initializer 'foreman_azure_rm.register_plugin', :before => :finisher_hook do
      Foreman::Plugin.register :foreman_azure_rm do
        requires_foreman '>= 1.17'
        compute_resource ForemanAzureRM::AzureRM
        parameter_filter ComputeResource, :azure_vm, :tenant, :app_ident, :secret_key, :sub_id, :region
      end
    end

    initializer "foreman_azure_rm.add_rabl_view_path" do
      Rabl.configure do |config|
        config.view_paths << ForemanAzureRM::Engine.root.join('app', 'views')
      end
    end

    initializer 'foreman_azure_rm.register_gettext', after: :load_config_initializers do
      locale_dir    = File.join(File.expand_path('../../../', __FILE__), 'locale')
      locale_domain = 'foreman_azure_rm'
      Foreman::Gettext::Support.add_text_domain locale_domain, locale_dir
    end

    config.to_prepare do
      require 'azure_mgmt_resources'
      require 'azure_mgmt_network'
      require 'azure_mgmt_storage'
      require 'azure_mgmt_compute'

      # Use excon as default so that HTTP Proxy settings of foreman works
      Faraday::default_adapter=:excon

      ::HostsController.send(:include, ForemanAzureRM::Concerns::HostsControllerExtensions)

      Api::V2::ComputeResourcesController.send(:include, ForemanAzureRM::Concerns::ComputeResourcesControllerExtensions)
    end

    rake_tasks do
      load "foreman_azure_rm.rake"
    end
  end
end
