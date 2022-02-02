def manage_plugins
  # It's been reported that a path set by DYLD_LIBRARY_PATH breaks
  # r10k gem installation. As such, it is picked up in globals, unset then set
  # after plugins are installed
  dyld_library_path = ENV['DYLD_LIBRARY_PATH']
  ENV['DYLD_LIBRARY_PATH']  = ''

  required_plugins = %w(inifile vagrant-address git r10k deep_merge sshkey highline vagrant-vbguest)
  
  # I had some clever code to remove the plugin if it's installed and you're at
  # > 2.0, but Vagrant complains before we even get here, so the user has to
  # remove it manually anyway.
  # if Vagrant.version?('< 2.1')
  if Gem::Version.new(Vagrant::VERSION) < Gem::Version.new('2.1')
    required_plugins.push('vagrant-triggers')
  end

  plugins_to_install = required_plugins.select { |plugin| !Vagrant.has_plugin? plugin }
  unless plugins_to_install.empty?
    puts "Installing plugins: #{plugins_to_install.join(' ')}"
    if system "vagrant plugin install #{plugins_to_install.join(' ')}"
      exec "vagrant #{ARGV.join(' ')}"
    else
      abort 'Installation of one or more plugins has failed. Aborting.'
    end
  end

  remove_plugins = %w(vagrant-proxy vagrant-aws vagrant-hostmanager vagrant-proxyconf vagrant-hosts vagrant-vmware-fusion)
  plugins_to_uninstall = remove_plugins.select { |plugin| Vagrant.has_plugin? plugin }
  unless plugins_to_uninstall.empty?
    puts "Un-installing plugins: #{plugins_to_uninstall.join(' ')}"
    if system "vagrant plugin uninstall #{plugins_to_uninstall.join(' ')}"
      exec "vagrant #{ARGV.join(' ')}"
    else
      abort 'Un-installation of one or more plugins has failed. Aborting.'
    end
  end

  # See comment above
  ENV['DYLD_LIBRARY_PATH'] = dyld_library_path
end
