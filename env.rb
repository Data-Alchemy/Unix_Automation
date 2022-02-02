# Set common variables based on environment

VAGRANT_DIR = File.expand_path("../..", __FILE__)

USER_CONFIG_DIR = File.join(ENV['HOME'], ".vagrant-config")
VAGRANT_CONFIG_DIR = ENV["VAGRANT_CONFIG_DIR"] || File.join(VAGRANT_DIR, "config")

TEMPLATE_CONFIG_DIR = File.join(VAGRANT_DIR, "templates", "vagrant-config")

DATASETS_DIR = File.join(VAGRANT_DIR, ".datasets")
OPEN_DATASETS_DIR = File.join(DATASETS_DIR, "open")
RESTRICTED_DATASETS_DIR = File.join(DATASETS_DIR, "restricted")

# Use Zymeworks Artifactory server for box lookups
# See: https://www.jfrog.com/confluence/display/RTF/Vagrant+Repositories
ENV['VAGRANT_SERVER_URL'] = 'https://artifactory.zymeworks.com/api/vagrant'

# Install gems into user home.
ENV['GEM_PATH'] = File.join(ENV['HOME'], ".vagrant.d", "gems", RUBY_VERSION)
ENV['PATH'] = File.join(ENV['GEM_PATH'], "bin") + ":" + ENV['PATH']

DATASETS_URL = 'https://datasets.zymeworks.com'
CONNECT_TIMEOUT = 1.5
SECONDS_PER_DAY = 86400.0

# Target Control Branch is the parent for all environment aliases (EL7+)
TARGET_CONTROL_BRANCH = 'testing'
