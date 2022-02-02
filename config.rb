require 'deep_merge'
require 'fileutils'
require 'readline'
require 'set'
require 'yaml'


class ConfigError < StandardError
  def initialize(msg="Configuration error has occurred")
    super
  end
end


# Parse Vagrant configuration from contents of a list of directores.
#
# Return configuration hash.
#
# Merge all found configuration specs, first to last.
#
# Spec can be a directory, file, or a hash.
# Validate configuration integrity before returning.
#
def load_config(*specs)
  config = {}
  specs.each do |spec|
    if spec.is_a? String
      if File.directory? spec
        part = parse_config_dir(spec)
      elsif File.file? spec
        part = YAML.load_file(spec)
      else
        raise ConfigError, "Configuration file/directory doesn't exist: #{spec}"
      end
    elsif spec.is_a? Hash
      part = spec
    else
      raise ConfigError, "#{spec} is not a valid configuration spec"
    end
    config = config.deep_merge!(part)
  end
  # Validate config
  validate_config(config)
end

# Validate the given configuration.
#
# Invalid configuration will be notified to the user and pruned
# from the config hash.
#
# Returns a subset of the given config with valid parameters.
def validate_config(config)
  boxes = config['boxes']
  nodes = config['nodes']

  # Make sure that at least one node is defined
  if !nodes || nodes.empty?
    raise ConfigError, 'No nodes defined in configuration'
  end

  all_datasets = Set[]

  verified_nodes = nodes.clone
  nodes.each do |name, details|
    # Provide defaults for CPU and Memory if not defined
    details['cpu'] || details['cpu'] = 1
    details['memory'] || details['memory'] = 512

    # Ensure all nodes have valid boxes
    if !details.key?('box')
      print_config_warning("Node #{name} is missing a box definition.")
      verified_nodes.delete(name)
      next
    elsif !boxes.key?(details['box'])
      print_config_warning("Node #{name} has an unknown box: #{details['box']}")
      verified_nodes.delete(name)
      next
    end

    # Check shares
    common_shares = config['shares']
    shares = [common_shares, details['shares']].flatten.compact
    if !shares.nil?
      # Ensure shares have valid keys
      shares.each do |share|
        if ! (share.key?('guest') && share.key?('host'))
          print_config_warning("Node #{name} has invalid share configuration. 'guest' and 'host' keys required")
          verified_nodes.delete(name)
          next
        end
      end

      # Ensure guest mount points of shares are unique
      guest_mounts = shares.map{|share| share['guest']}

      if guest_mounts.uniq.length != guest_mounts.length
        print_config_warning("Node #{name} has invalid shares. Duplicate guest mount points found.")
        verified_nodes.delete(name)
        next
      end
    end

    # Check datasets
    #
    # Datasets are currently mounted using NFS. We cannot have two VMs that try
    # to export paths where one is a subpath of the other (NFS doesn't like
    # this).
    datasets = details['datasets']
    datasets_valid = true
    if !datasets.nil?
      datasets.each do |dataset|
        all_datasets.each do |a|
          # We haven't bothered with full path checking here - not really necessary.
          if a != dataset and (a.start_with?(dataset) or dataset.start_with?(a))
            datasets_valid = false
            print_config_warning("Node '#{name}' has datasets that conflict with those found in other nodes: #{a}, #{dataset}")
          end
        end
      end

      if !datasets_valid
        verified_nodes.delete(name)
      else
        all_datasets.merge(datasets)
      end
    end

    # Assign details back to node
    nodes[name] = details
  end

  config['nodes'] = verified_nodes

  return config
end


# Reads YAML files from the given path and merges them into a single hash.
#
def parse_config_dir(path)
  output = {}
  files = Dir.glob(File.join(path, '*.yml'))
  files && files.each do |f|
    output = output.deep_merge(YAML.load_file(f))
  end
  return output
end


# Setup dotfiles in user home directory, if necessary.
#
def ensure_user_config(user_config_dir, template_config_dir, inputf=method(:input))
  user_config_file = File.join(user_config_dir, 'config.yml')
  if File.file? user_config_file
    return
  end

  puts
  puts "=========================================="
  puts "Vagrant initial setup"
  puts "=========================================="
  puts

  begin
    puts "Code folder location"
    code_dir = inputf.call()
  end until code_dir != ""

  code_dir = File.expand_path(code_dir)

  if !File.directory?(code_dir)

    begin
      puts
      puts "The path #{code_dir} does not exist."
      puts "This path is required for vagrant to function properly."
      puts "Would you like to create it? (yes/no)"
      puts
      puts "(Selecting no will quit Vagrant setup)"
      create_dir = inputf.call().downcase
    end until ["yes", "y", "no", "n"].include?(create_dir)

    case create_dir.chars.first
    when "y"
      create_dir(code_dir)
    when "n"
      raise ConfigError, "Quitting vagrant setup..."
    end

  end

  # Create config directory
  create_dir(user_config_dir)

  # Copy config
  File.open(user_config_file, 'w') do |file|
    template_path = File.join(template_config_dir, 'config.yml')
    file.puts File.read(template_path).gsub(/__CODE__/, code_dir)
  end

end


# Prompt and attempt to create directory at path.
#
def create_dir(path)
  puts "Creating #{path}"
  begin
    FileUtils.mkdir_p(path)
  rescue
    raise ConfigError, "Unable to create path: #{path}. Please ensure you have write permissions."
  end
end


def print_config_warning(message)
  puts
  puts "############################################################"
  puts "WARNING: #{message}"
  puts "         Please check your node configuration."
  puts "############################################################"
  puts
end

# Prompt user for input
#
def input(prompt="> ", newline=false)
  prompt += "\n" if newline
  Readline.readline(prompt, true).squeeze(" ").strip
end
