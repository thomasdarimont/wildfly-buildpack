# Encoding: utf-8
# Cloud Foundry Java Buildpack
# Copyright 2013 the original author or authors.
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

require 'pathname'
require 'java_buildpack/util'

module JavaBuildpack
  module Util

    # Utilities for dealing with Spring Boot applications
    class SpringBootUtils

      private_class_method :new

      class << self

        # Indicates whether a application is a Spring Boot application
        #
        # @param [Application] application the application to search
        # @return [Boolean] +true+ if the application is a Spring Boot application, +false+ otherwise
        def is?(application)
          (application.root + SPRING_BOOT_CORE_FILE_PATTERN).glob.any?
        end

        # The version of Spring Boot used by the application
        #
        # @param [Application] application the application to search
        # @return [String] the version of Spring Boot used by the application
        def version(application)
          (application.root + SPRING_BOOT_CORE_FILE_PATTERN).glob.first.to_s.match(/.*spring-boot-([^-]*)\.jar/)[1]
        end

        SPRING_BOOT_CORE_FILE_PATTERN = '**/lib/spring-boot-*.jar'.freeze

        private_constant :SPRING_BOOT_CORE_FILE_PATTERN

      end

    end

  end
end
