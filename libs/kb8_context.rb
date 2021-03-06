require_relative 'kb8_utils'
require_relative 'kb8_run'

class Kb8Context

  attr_accessor :cluster,
                :name,
                :namespace,
                :user

  CMD_CONFIG_VIEW = "#{Kb8Run::CMD_KUBECTL} config view -o yaml"

  def initialize(context)
    context_setting = nil
    case context.class.to_s
      when 'Hash'
        context_setting = context
      when 'String'
        @name = context
        all_config = Kb8Run.get_yaml_data(CMD_CONFIG_VIEW)
        all_config['contexts'].each do |a_context|
          if a_context['name'] == context
            context_setting = a_context['context']
            break
          end
        end
        unless context_setting
          raise "Context '#{@name}' not found"
        end
      when 'Kb8Context'
        context_setting = context
      else
        raise 'Invalid context, expecting Hash'
    end
    unless context_setting['cluster'] && context_setting['namespace']
      raise 'Invalid context, expecting at least a cluster and namespace.'
    end
    @cluster = context_setting['cluster']
    @namespace = context_setting['namespace']
    if context_setting['name']
      @name = context_setting['name']
    else
      @name = @namespace
    end
    @user = context_setting['user']
  end

  def [](key)
    case key
      when 'name'
        @name
      when 'namespace'
        @namespace
      when 'cluster'
        @cluster
      when 'user'
        @user
      else
        nil
    end
  end

end