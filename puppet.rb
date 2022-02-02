# Manage the dynamic environment used by the puppet provisioner

require 'fileutils'
require 'yaml'
require 'inifile'

R10K_CONFIG = "---
sources:
  puppet-control:
    remote: https://gitlab.zymeworks.com/%{namespace}/puppet-control.git
    basedir: ./environments/
deploy:
  purge_levels: [ 'environment', 'puppetfile' ]
forge:
  baseurl: 'https://artifactory.zymeworks.com/api/puppet/forge'
"

# Check for a Puppetfile in a given repo path. It's absence triggers an R10k
# deployment
def has_puppetfile?(path)
  File.file?(File.join(path, 'Puppetfile'))
end

# do_symlink wraps do_r10k if either the repo is managed (always checked/update)
# or appears absent. The end result would be an aliasing of the specified
# puppet provisioner 'environment' to the upstream TARGET_CONTROL_BRANCH repo.
def do_symlink(repo, managed)
  env_path  = File.join(VAGRANT_DIR, 'puppet', 'environments')
  repo_path = File.join(env_path, TARGET_CONTROL_BRANCH)
  FileUtils.mkdir_p env_path
  # Deploy the environment if managed or if it appears empty
  do_r10k(TARGET_CONTROL_BRANCH) if managed or !has_puppetfile?(repo_path)

  Dir.chdir(env_path) do
    puts "Notice: creating/updating Control Repo alias(es)"
    begin
      File.symlink?(repo) && File.delete(repo)
      File.symlink(TARGET_CONTROL_BRANCH, repo)
    rescue
      puts "Failed to create Control Repo alias: #{repo}. Provisioning may fail"
    end
  end
end

# Return a list of environments used by puppet provisioners from configs
def get_provisioner_envs(config_yaml)
  nodes = config_yaml['nodes']
  provisioners = []
  environments = []
  begin
    nodes.each do | node, hash |
      provisioner = hash['provisioners'].select  { | provisioner |
        provisioner['puppet']
      }
      provisioners << provisioner
    end
    provisioners.flatten.uniq.each do | p |
      conf = p['puppet']
      environments << conf['environment']
    end
    # The presence of TARGET_CONTROL_BRANCH in a config will break things
    environments.delete(TARGET_CONTROL_BRANCH)
    environments.flatten.uniq
  rescue
    ['vagrant']
  end
end

# Users can optionally customize the puppet configuration file used when
# provisioning in the VM.  See https://wiki.zymeworks.com/x/ooGpBw for details.
def puppet_conf(node, node_name, config)
  puts "    #{node_name}: Updating puppet/puppet.conf"
  inifile = VAGRANT_DIR + '/puppet/puppet.conf'
  if File.exists?(inifile)
    ini = IniFile.load(inifile)
  else
    ini = IniFile.new(:content => "[main]\nstrict=off", :filename => inifile)
  end
  # Write all ini sections found in conf keys
  config['conf'].each do | s, h |
    current = ini[s]
    ini[s] = current.merge(h)
  end
  ini.write
end

# manage symlink aliases to the target control repository
def stage_puppet(root, config_yaml)
  puppet_root  = File.join(root, "puppet")
  env_path     = File.join(puppet_root, 'environments')
  environments = get_provisioner_envs(config_yaml)

  # only in cases where the physical repo does not appear to present,
  # we deploy it before aliasing
  ['vagrant', 'devel'].each do | repo |
    repo_path = File.join(env_path , repo)
    unless File.exists?(File.join(repo_path, 'Puppetfile'))
      puts "Notice: Fetching Puppet code into #{repo} environment..."
      ensure_repo(repo, true)
    end
  end

  # Find, delete all symlinks. Create only those in config_yaml
  Dir.chdir(env_path) do
    Dir.entries('.').select { | entry |
      File.symlink?(entry)
    }.each { | link |
      File.delete(link)
    }
    # Archive any pre-existing folders (legacy) that match
    # environments we wish to alias and create symlinks
    environments.each {| env |
      unless env == 'vagrant'
        File.symlink(TARGET_CONTROL_BRANCH, env)
      end
    }
  end
end

# Deploy a Puppet Control repo using r10k
def do_r10k(repo)
  env_root = File.join(VAGRANT_DIR, 'puppet')
  FileUtils.mkdir_p env_root

  File.open(File.join(env_root, 'r10k.yaml'), 'w') do | file |
    file.write(R10K_CONFIG % {:namespace => $namespace})
  end

  Dir.chdir(env_root) do
    `r10k deploy environment #{repo} --puppetfile`
    if $?.exitstatus != 0
      warn "unable to sync puppet environment with r10k. provisioning may fail."
    end
  end
end

# ensure_repo determines how to setup and/or update a defined Puppet control
# repo.
def ensure_repo(environment, manage)
  case environment
  when 'vagrant'           # Legacy non-linked vagrant source
    do_r10k(environment)
  when 'testing'           # Do not allow 'testing' environment in Vagrant
    abort  "Cannot provision using puppet environment \'testing\'!".red +
           " Please change your VM configuration and try again.".red
  else
    do_symlink(environment, manage) # Failing the above, deploy a symlinked repo
  end
end

# Update environments from Puppet control repo.
def update_puppet_envs(node, node_details, config, node_name)
  environments = config["environments"]
  puppet_provisioner = node_details['provisioners'].select {
                        | provisioner | provisioner['puppet']
                       }
  puppet_data = puppet_provisioner.first
  environment = puppet_data['puppet']['environment']
  environment_path = puppet_data['puppet']['environment_path']
  FileUtils.mkdir_p File.join(VAGRANT_DIR, environment_path)
  ensure_repo(environment, environments["manage"])
  puppet_conf(node, node_name, config['puppet']) if config.key? 'puppet'

  # Create a host classification entry if the VM config contains hiera data
  if node_details.key?('hiera')
    hostname = node_details["hostname"]
    env_dir = File.join(VAGRANT_DIR, 'puppet', 'environments', environment)
    path = File.join(env_dir, 'hieradata', 'hosts', "#{hostname}.yaml")
    File.open(path, 'w') do | file |
      file.write(node_details['hiera'].to_yaml)
    end
  end
end
