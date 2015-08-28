require 'methadone'
require_relative 'kb8_run'
require 'uri'

class Deploy

  attr_accessor :deploy_units,
                :context,
                :tunnel

  YAML_DEPLOY_PATH = 'path'
  SSH_SOCKET = '/tmp/kb8or-ctrl-socket'

  include Methadone::Main
  include Methadone::CLILogging

  def initialize(deploy_file,
                 always_deploy=false,
                 env_name=nil,
                 tunnel=nil,
                 tunnel_options=nil,
                 overridden_params=nil)

    @deploy_units = []
    deploy_home = File.dirname(deploy_file)

    # Load the deployment file as YAML...
    debug "Loading file:#{deploy_file}..."
    deploy_data = YAML.load(File.read(deploy_file))

    @tunnel = tunnel
    @tunnel_options = tunnel_options

    # Load default settings
    settings = Settings.new(deploy_home)
    settings.update(deploy_data)

    # Load container image version information (per image name)
    if settings.container_version_glob_path
      # TODO: check if version path is rooted...
      container_version_path = File.join(deploy_home, settings.container_version_glob_path)
      debug "Container version path:#{container_version_path}"
      container_version_finder = ContainerVersionFinder.new(container_version_path)
    end

    # Create a context object for informing each deployment...
    @context = Context.new(settings,
                           container_version_finder,
                           deploy_home,
                           always_deploy,
                           env_name,
                           overridden_params)

    @context.environment
    # Load deployment information for each 'deploy' (kb8 directory) that exists
    deploy_data['Deploys'].each do | deploy_unit |
      @deploy_units << Kb8DeployUnit.new(deploy_unit, @context)
    end
  end

  # Method to carry out the deployments
  def deploy
    # Ensure that the config is updated...
    begin
      uri = URI(@context.settings.kb8_server)
      if @tunnel
        ssh_cmd = "ssh #{@tunnel_options} -M -S #{SSH_SOCKET} -fnNT #{@tunnel} " +
                  " -L #{uri.port}:#{uri.host}:#{uri.port}"

        debug "Running:\n#{ssh_cmd}"
        Process.spawn(ssh_cmd)
        @context.settings.kb8_server = "#{uri.scheme}://localhost:#{uri.port}"
        # TODO: poll for readyness...
        puts "Waiting for SSH tunnel..."
        sleep 5
      end
      Kb8Run.update_environment(@context.env_name + '-tunnel', @context.settings.kb8_server)
      @deploy_units.each do | deploy_unit |
        deploy_unit.deploy
      end
    ensure
      if @tunnel
        `ssh -S #{SSH_SOCKET} -O exit #{@tunnel}`
      end
    end
  end
end
