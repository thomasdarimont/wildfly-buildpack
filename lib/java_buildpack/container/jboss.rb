# Encoding: utf-8
# Cloud Foundry Java Buildpack
# Copyright (c) 2013 the original author or authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'java_buildpack/container'
require 'java_buildpack/container/container_utils'
require 'java_buildpack/util/format_duration'
require 'java_buildpack/util/java_main_utils'
require 'java_buildpack/versioned_dependency_component'
require 'tmpdir'

module JavaBuildpack::Container

  # Encapsulates the detect, compile, and release functionality for applications running Spring Boot CLI
  # applications.
  class Jboss < JavaBuildpack::VersionedDependencyComponent

    def initialize(context)
      super('JBoss', context)
    end

    def compile
      download { |file| expand file }
      parameterise_http_port
      disable_welcome_root
      link_application
      create_dodeploy
    end

    def release
      @java_opts << '-Dhttp.port=$PORT'

      java_home_string = "JAVA_HOME=#{@java_home}"
      java_opts_string = ContainerUtils.space("JAVA_OPTS=\"#{ContainerUtils.to_java_opts_s(@java_opts)}\"")

      "#{java_home_string}#{java_opts_string} #{JBOSS_HOME}/bin/standalone.sh -b 0.0.0.0"
    end

    protected

    def supports?
      web_inf? && !JavaBuildpack::Util::JavaMainUtils.main_class(@app_dir)
    end

    private

    WEB_INF_DIRECTORY = 'WEB-INF'.freeze

    JBOSS_HOME = '.jboss'.freeze

    def link_application
      FileUtils.rm_rf root
      FileUtils.mkdir_p root
      @application.children.each { |child| FileUtils.ln_sf child.relative_path_from(root), root }
    end

    def web_inf?
      @application.child(WEB_INF_DIRECTORY).exist?
    end

    def expand(file)
      expand_start_time = Time.now
      print "       Expanding #{@component_name} to #{JBOSS_HOME} "

      Dir.mktmpdir do |tmpdir_root|
        shell "rm -rf #{jboss_home}"
        shell "mkdir -p #{jboss_home}"
        shell "tar xzf #{file.path} -C #{jboss_home} --strip 1 2>&1"
      end

      puts "(#{(Time.now - expand_start_time).duration})"
    end

    def jboss_home
      File.join @app_dir, JBOSS_HOME
    end

    def parameterise_http_port
      standalone_config = "#{jboss_home}/standalone/configuration/standalone.xml"
      original = File.open(standalone_config, 'r') { |f| f.read }
      modified = original.gsub(/<socket-binding name="http" port="8080"\/>/, '<socket-binding name="http" port="${http.port}"/>')
      File.open(standalone_config, 'w') { |f| f.write modified }
    end

    def disable_welcome_root
      standalone_config = "#{jboss_home}/standalone/configuration/standalone.xml"
      original = File.open(standalone_config, 'r') { |f| f.read }
      modified = original.gsub(/<virtual-server name="default-host" enable-welcome-root="true">/, '<virtual-server name="default-host" enable-welcome-root="false">')
      File.open(standalone_config, 'w') { |f| f.write modified }
    end

    def root
      webapps + 'ROOT.war'
    end

    def jboss_home
      @application.component_directory 'jboss'
    end

    def webapps
      jboss_home + 'standalone' + 'deployments'
    end

    def create_dodeploy
      FileUtils.touch(webapps + 'ROOT.war.dodeploy')
    end

  end

end
