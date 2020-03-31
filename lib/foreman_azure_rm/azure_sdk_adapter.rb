module ForemanAzureRm
  class AzureSdkAdapter
    def initialize(tenant, app_ident, secret_key, sub_id, gov_cloud)
      @tenant           = tenant
      @app_ident        = app_ident
      @secret_key       = secret_key
      @sub_id           = sub_id
      @gov_cloud        = gov_cloud
    end

    def resource_endpoint
      binding.pry
      if @gov_cloud
        MsRestAzure::AzureEnvironments::AzureUSGovernment.resource_manager_endpoint_url
      else
        MsRestAzure::AzureEnvironments::AzureCloud.resource_manager_endpoint_url
      end
    end

    def resource_client
      # binding.pry
      @resource_client ||= Azure::Resources::Mgmt::V2019_07_01::ResourceManagementClient.new(azure_credentials(@gov_cloud), resource_endpoint)
      @resource_client.subscription_id = @sub_id
      @resource_client
    end

    def compute_client
      @compute_client ||= Azure::Resources::Mgmt::V2019_07_01::ComputeManagementClient.new(azure_credentials(@gov_cloud), resource_endpoint)
      @compute_client.subscription_id = @sub_id
      @compute_client
    end

    def network_client
      @network_client ||= Azure::Resources::Mgmt::V2019_07_01::NetworkManagementClient.new(azure_credentials(@gov_cloud), resource_endpoint)
      @network_client.subscription_id = @sub_id
      @network_client
    end

    def storage_client
      @storage_client ||= Azure::Resources::Mgmt::V2019_07_01::StorageManagementClient.new(azure_credentials(@gov_cloud), resource_endpoint)
      @storage_client.subscription_id = @sub_id
      @storage_client
    end

    def settings_for_azure_env(environment)
      if environment == "AzureUSGovernment"
        MsRestAzure::ActiveDirectoryServiceSettings.get_azure_us_government_settings
      else
        MsRestAzure::ActiveDirectoryServiceSettings.get_azure_settings
      end
    end

    def azure_credentials(gov_cloud = nil)
      binding.pry
      if gov_cloud
        environment = "AzureUSGovernment"
      else
        environment = "AzureCloud"
      end
      provider = MsRestAzure::ApplicationTokenProvider.new(@tenant, @app_ident, @secret_key, settings_for_azure_env(environment))
      credentials = MsRest::TokenCredentials.new(provider)
    end

    def rgs
      rgs      = resource_client.resource_groups.list
      rgs.map(&:name)
    end

    def vnets
      network_client.virtual_networks.list_all
    end

    def subnets(rg_name, vnet_name)
      network_client.subnets.list(rg_name, vnet_name)
    end

    def public_ip(rg_name, pip_name)
      network_client.public_ipaddresses.get(rg_name, pip_name)
    end

    def vm_nic(rg_name,nic_name)
      network_client.network_interfaces.get(rg_name, nic_name)
    end

    def get_vm_extension(rg_name, vm_name, vm_extension_name)
      compute_client.virtual_machine_extensions.get(rg_name, vm_name, vm_extension_name)
    end

    def list_vm_sizes(region)
      return [] unless region.present?
      stripped_region = region.gsub(/\s+/, '').downcase
      compute_client.virtual_machine_sizes.list(stripped_region).value()
    end

    def list_vms(region)
      # List all VMs in a resource group
      virtual_machines = compute_client.virtual_machines.list_by_location(region)
    end

    def get_vm(rg_name, vm_name)
      compute_client.virtual_machines.get(rg_name, vm_name)
    end

    def get_storage_accts
      result = storage_client.storage_accounts.list
      result.value
    end

    def create_or_update_vm(rg_name, vm_name, parameters)
      compute_client.virtual_machines.create_or_update(rg_name, vm_name, parameters)
    end

    def create_or_update_vm_extensions(rg_name, vm_name, vm_extension_name, extension_params)
      compute_client.virtual_machine_extensions.create_or_update(rg_name,
                                                          vm_name,
                                                          vm_extension_name,
                                                          extension_params) 
    end

    def create_or_update_pip(rg_name, pip_name, parameters)
      network_client.public_ipaddresses.create_or_update(rg_name, pip_name, parameters)
    end

    def create_or_update_nic(rg_name, nic_name, parameters)
      network_client.network_interfaces.create_or_update(rg_name, nic_name, parameters)
    end

    def delete_pip(rg_name, pip_name)
      network_client.public_ipaddresses.delete(rg_name, pip_name)
    end

    def delete_nic(rg_name, nic_name)
      network_client.network_interfaces.delete(rg_name, nic_name)
    end

    def delete_vm(rg_name, vm_name)
      compute_client.virtual_machines.delete(rg_name, vm_name)
    end

    def delete_disk(rg_name, osdisk_name)
      compute_client.disks.delete(rg_name, osdisk_name)
    end

    def check_vm_status(rg_name, vm_name)
      virtual_machine = compute_client.virtual_machines.get(rg_name, vm_name, expand:'instanceView')
      get_status(virtual_machine)
    end

    def get_status(virtual_machine)
      vm_statuses = virtual_machine.instance_view.statuses
      vm_status = nil
      vm_statuses.each do |status|
        if status.code.include? 'PowerState'
          vm_status = status.code.split('/')[1]
        end
      end
      vm_status
    end

    def start_vm(rg_name, vm_name)
      compute_client.virtual_machines.start(rg_name, vm_name)
    end

    def stop_vm(rg_name, vm_name)
      compute_client.virtual_machines.power_off(rg_name, vm_name)
      compute_client.virtual_machines.deallocate(rg_name, vm_name)
    end
  end
end
